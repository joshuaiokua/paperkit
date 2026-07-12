from pathlib import Path
import hashlib
import io
import json
import os
import re
import shutil
import signal
import socket
import struct
import subprocess
import tarfile
import tempfile
import time
import unittest
from urllib.error import HTTPError, URLError
from urllib.request import urlopen


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "sample" / "preview-research-paper.sh"
OUTPUT = ROOT / "tmp" / "research-paper-preview"
FIXTURE_PDF = ROOT / "sample" / "research-paper.pdf"
STATIC_FILES = (
    "index.html",
    "preview.css",
    "preview.mjs",
    "state.mjs",
    "controller.mjs",
    "clipboard.mjs",
)


def png_dimensions(path):
    with path.open("rb") as file:
        signature = file.read(24)
    if signature[:8] != b"\x89PNG\r\n\x1a\n":
        raise AssertionError(f"not a PNG: {path}")
    return struct.unpack(">II", signature[16:24])


def unused_port():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


def stop_process(process):
    if process.poll() is None:
        process.send_signal(signal.SIGINT)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.terminate()
            process.wait(timeout=5)
    if process.stdout:
        process.stdout.close()
    if process.stderr:
        process.stderr.close()


def wait_for_url(url, timeout=10):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            return urlopen(url, timeout=1)
        except (OSError, URLError):
            time.sleep(0.05)
    raise AssertionError(f"server did not become ready: {url}")


class PreviewScriptTests(unittest.TestCase):
    def run_preview(self, *args, env=None):
        return subprocess.run(
            ["/bin/bash", str(SCRIPT), *args],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
            env={**os.environ, **(env or {})},
        )

    def test_help_documents_the_supported_commands_and_dependencies(self):
        self.assertTrue(SCRIPT.exists(), "preview script is not implemented")

        result = self.run_preview("--help")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("preview-research-paper.sh [render]", result.stdout)
        self.assertIn("PAPERKIT_PREVIEW_PORT", result.stdout)
        self.assertIn("pdftoppm", result.stdout)
        self.assertIn("pypdf", result.stdout)
        self.assertIn("sample/preview/SMOKE.md", result.stdout)

    def test_unknown_command_returns_usage_error(self):
        result = self.run_preview("unknown")

        self.assertEqual(result.returncode, 2)
        self.assertIn("Usage: preview-research-paper.sh [render]", result.stderr)

    def test_extra_arguments_return_usage_error(self):
        result = self.run_preview("render", "extra")

        self.assertEqual(result.returncode, 2)
        self.assertIn("Usage: preview-research-paper.sh [render]", result.stderr)

    def test_port_must_be_an_integer_in_the_tcp_range(self):
        for value in ("zero", "0", "65536", "1.5", "9" * 100):
            with self.subTest(value=value):
                result = self.run_preview(
                    "render",
                    env={"PAPERKIT_PREVIEW_PORT": value},
                )

                self.assertEqual(result.returncode, 2)
                self.assertIn(
                    "PAPERKIT_PREVIEW_PORT must be an integer from 1 to 65535",
                    result.stderr,
                )

    def test_missing_pdftoppm_fails_before_rendering(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "dirname").symlink_to("/usr/bin/dirname")
            (path / "python3").symlink_to("/usr/bin/python3")

            result = self.run_preview("render", env={"PATH": str(path)})

        self.assertEqual(result.returncode, 2)
        self.assertIn("pdftoppm is required", result.stderr)

    def test_missing_python_and_uv_fails_before_rendering(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "dirname").symlink_to("/usr/bin/dirname")
            pdftoppm = path / "pdftoppm"
            pdftoppm.write_text("#!/bin/sh\nexit 0\n")
            pdftoppm.chmod(0o755)

            result = self.run_preview("render", env={"PATH": str(path)})

        self.assertEqual(result.returncode, 2)
        self.assertIn("python3 with pypdf, or uv, is required", result.stderr)

    def test_render_publishes_the_validated_pdf_and_rasterized_pages(self):
        status_before = subprocess.check_output(
            ["git", "status", "--porcelain=v1", "--untracked-files=all"],
            cwd=ROOT,
            text=True,
        )
        fixture_before = (
            hashlib.sha256(FIXTURE_PDF.read_bytes()).hexdigest()
            if FIXTURE_PDF.exists()
            else None
        )

        result = self.run_preview("render")

        self.assertEqual(result.returncode, 0, result.stderr)
        manifest_path = OUTPUT / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        self.assertEqual(manifest["schemaVersion"], 1)
        self.assertRegex(manifest["pdfSha256"], r"^[0-9a-f]{64}$")
        self.assertEqual(manifest["pageCount"], 4)

        artifact = OUTPUT / "artifacts" / manifest["pdfSha256"]
        pdf = artifact / "research-paper.pdf"
        self.assertEqual(
            hashlib.sha256(pdf.read_bytes()).hexdigest(),
            manifest["pdfSha256"],
        )
        pages = sorted(
            artifact.glob("page-*.png"),
            key=lambda path: int(re.search(r"(\d+)$", path.stem).group(1)),
        )
        self.assertEqual(
            [path.name for path in pages],
            ["page-1.png", "page-2.png", "page-3.png", "page-4.png"],
        )
        self.assertTrue(all(png_dimensions(page) == (1224, 1584) for page in pages))
        self.assertFalse((OUTPUT / ".render.lock").exists())
        self.assertEqual(list(OUTPUT.glob(".stage.*")), [])
        self.assertEqual(
            hashlib.sha256(FIXTURE_PDF.read_bytes()).hexdigest()
            if FIXTURE_PDF.exists()
            else None,
            fixture_before,
            "render mode must not touch sample/research-paper.pdf",
        )

        obsolete = OUTPUT / "artifacts" / ("a" * 64)
        obsolete.mkdir(exist_ok=True)
        second = self.run_preview("render")

        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(json.loads(manifest_path.read_text()), manifest)
        self.assertFalse(obsolete.exists())
        self.assertEqual(
            sorted(path.name for path in (OUTPUT / "artifacts").iterdir()),
            [manifest["pdfSha256"]],
        )
        self.assertEqual(
            subprocess.check_output(
                ["git", "status", "--porcelain=v1", "--untracked-files=all"],
                cwd=ROOT,
                text=True,
            ),
            status_before,
            "render mode must not change tracked or untracked repository state",
        )

    def test_concurrent_render_fails_without_disturbing_the_lock(self):
        OUTPUT.mkdir(parents=True, exist_ok=True)
        lock = OUTPUT / ".render.lock"
        lock.mkdir(exist_ok=True)
        (lock / "pid").write_text(f"{os.getpid()}\n")
        self.addCleanup(shutil.rmtree, lock, True)

        result = self.run_preview("render")

        self.assertEqual(result.returncode, 2)
        self.assertIn("another preview render is already running", result.stderr)
        self.assertIn(str(lock), result.stderr)
        self.assertIn("remove", result.stderr)
        self.assertTrue(lock.exists())

    def test_stale_lock_and_its_owned_stage_are_reclaimed(self):
        OUTPUT.mkdir(parents=True, exist_ok=True)
        stale_pid = "99999999"
        lock = OUTPUT / ".render.lock"
        shutil.rmtree(lock, ignore_errors=True)
        lock.mkdir()
        (lock / "pid").write_text(f"{stale_pid}\n")
        stage = OUTPUT / f".stage.{stale_pid}.abandoned"
        stage.mkdir()
        (stage / "partial").write_text("incomplete")

        result = self.run_preview("render")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(lock.exists())
        self.assertFalse(stage.exists())

    def test_poppler_padded_page_names_are_published_canonically(self):
        shutil.rmtree(OUTPUT, ignore_errors=True)
        self.addCleanup(self.run_preview, "render")
        self.addCleanup(shutil.rmtree, OUTPUT, True)
        with tempfile.TemporaryDirectory() as directory:
            pdftoppm = Path(directory) / "pdftoppm"
            pdftoppm.write_text(
                "#!/bin/sh\n"
                "for output do :; done\n"
                "page=1\n"
                "while [ \"$page\" -le 12 ]; do\n"
                "  padded=$(printf '%02d' \"$page\")\n"
                "  printf 'png' > \"${output}-${padded}.png\"\n"
                "  page=$((page + 1))\n"
                "done\n"
            )
            pdftoppm.chmod(0o755)

            result = self.run_preview(
                "render",
                env={"PATH": f"{directory}:{os.environ['PATH']}"},
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        manifest = json.loads((OUTPUT / "manifest.json").read_text())
        self.assertEqual(manifest["pageCount"], 12)
        artifact = OUTPUT / "artifacts" / manifest["pdfSha256"]
        self.assertEqual(
            sorted(
                (path.name for path in artifact.glob("page-*.png")),
                key=lambda name: int(re.search(r"(\d+)", name).group(1)),
            ),
            [f"page-{page}.png" for page in range(1, 13)],
        )

    def test_failed_rasterization_preserves_the_last_good_generation(self):
        initial = self.run_preview("render")
        self.assertEqual(initial.returncode, 0, initial.stderr)
        manifest = (OUTPUT / "manifest.json").read_bytes()

        with tempfile.TemporaryDirectory() as directory:
            failing = Path(directory) / "pdftoppm"
            failing.write_text("#!/bin/sh\nexit 9\n")
            failing.chmod(0o755)
            result = self.run_preview(
                "render",
                env={"PATH": f"{directory}:{os.environ['PATH']}"},
            )

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((OUTPUT / "manifest.json").read_bytes(), manifest)
        self.assertFalse((OUTPUT / ".render.lock").exists())
        self.assertEqual(list(OUTPUT.glob(".stage.*")), [])

    def test_render_copies_only_the_static_companion_allowlist(self):
        source = ROOT / "sample" / "preview"
        for filename in STATIC_FILES:
            self.assertTrue((source / filename).exists(), f"missing {filename}")

        unlisted = source / "unlisted.txt"
        unlisted.write_text("must not be served")
        self.addCleanup(unlisted.unlink, missing_ok=True)
        result = self.run_preview("render")

        self.assertEqual(result.returncode, 0, result.stderr)
        for filename in STATIC_FILES:
            published = OUTPUT / filename
            self.assertEqual(published.read_bytes(), (source / filename).read_bytes())
            self.assertFalse(published.is_symlink())
        self.assertFalse((OUTPUT / unlisted.name).exists())
        self.assertFalse((OUTPUT / "SMOKE.md").exists())

    def test_no_argument_serves_only_the_output_root_on_loopback(self):
        port = unused_port()
        process = subprocess.Popen(
            ["/bin/bash", str(SCRIPT)],
            cwd=ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env={**os.environ, "PAPERKIT_PREVIEW_PORT": str(port)},
        )
        self.addCleanup(stop_process, process)
        base = f"http://127.0.0.1:{port}"

        with wait_for_url(f"{base}/index.html") as response:
            self.assertIn(b"Research paper preview", response.read())
        with wait_for_url(f"{base}/manifest.json") as response:
            manifest = json.load(response)
        artifact = f"{base}/artifacts/{manifest['pdfSha256']}"
        with wait_for_url(f"{artifact}/research-paper.pdf") as response:
            self.assertEqual(response.status, 200)
        with wait_for_url(f"{artifact}/page-1.png") as response:
            self.assertEqual(response.status, 200)

        for private_path in ("/.git/config", "/sample/research-paper.md"):
            with self.subTest(private_path=private_path):
                with self.assertRaises(HTTPError) as error:
                    urlopen(f"{base}{private_path}", timeout=2)
                self.assertEqual(error.exception.code, 404)
                error.exception.close()

        command = subprocess.run(
            ["ps", "-p", str(process.pid), "-o", "command="],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        self.assertIn("http.server", command)
        self.assertIn("--bind 127.0.0.1", command)
        self.assertIn(f"--directory {OUTPUT}", command)

        stop_process(process)
        with self.assertRaises(OSError):
            socket.create_connection(("127.0.0.1", port), timeout=0.5)

    def test_occupied_port_fails_clearly_without_stopping_the_listener(self):
        with socket.socket() as listener:
            listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            listener.bind(("127.0.0.1", 0))
            listener.listen()
            port = listener.getsockname()[1]

            result = self.run_preview(
                env={"PAPERKIT_PREVIEW_PORT": str(port)},
            )

            self.assertEqual(result.returncode, 2)
            self.assertIn(
                f"port {port} is already in use; set PAPERKIT_PREVIEW_PORT",
                result.stderr,
            )
            self.assertGreaterEqual(listener.fileno(), 0)

    def test_preview_sources_are_ignored_by_the_release_archive(self):
        paths = [
            "sample/preview-research-paper.sh",
            "sample/preview/index.html",
            "sample/preview/preview.css",
            "sample/preview/preview.mjs",
            "sample/preview/state.mjs",
            "sample/preview/controller.mjs",
            "sample/preview/clipboard.mjs",
            "sample/preview/SMOKE.md",
            "tests/test_preview_script.py",
            "tests/test_preview_companion.mjs",
        ]
        attributes = subprocess.run(
            ["git", "check-attr", "export-ignore", "--", *paths],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        for path in paths:
            self.assertIn(f"{path}: export-ignore: set", attributes)

        ignored = subprocess.run(
            ["git", "check-ignore", "-q", "tmp/research-paper-preview/manifest.json"],
            cwd=ROOT,
            check=False,
        )
        self.assertEqual(ignored.returncode, 0)

        with tempfile.TemporaryDirectory() as directory:
            repository = Path(directory)
            (repository / "sample").mkdir()
            (repository / "tests").mkdir()
            shutil.copy(ROOT / ".gitattributes", repository / ".gitattributes")
            shutil.copy(SCRIPT, repository / "sample" / SCRIPT.name)
            shutil.copytree(ROOT / "sample" / "preview", repository / "sample" / "preview")
            shutil.copy(
                ROOT / "tests" / "test_preview_script.py",
                repository / "tests" / "test_preview_script.py",
            )
            shutil.copy(
                ROOT / "tests" / "test_preview_companion.mjs",
                repository / "tests" / "test_preview_companion.mjs",
            )
            subprocess.run(["git", "init", "-q"], cwd=repository, check=True)
            subprocess.run(["git", "add", "."], cwd=repository, check=True)
            subprocess.run(
                [
                    "git",
                    "-c",
                    "user.name=Paperkit Test",
                    "-c",
                    "user.email=paperkit@example.invalid",
                    "commit",
                    "-qm",
                    "fixture",
                ],
                cwd=repository,
                check=True,
            )
            archive = subprocess.check_output(
                ["git", "archive", "--format=tar", "HEAD"],
                cwd=repository,
            )
            with tarfile.open(fileobj=io.BytesIO(archive), mode="r:") as release:
                names = release.getnames()

        self.assertFalse(
            any(
                name == "sample/preview-research-paper.sh"
                or name == "sample/preview"
                or name.startswith("sample/preview/")
                or name in {
                    "tests/test_preview_script.py",
                    "tests/test_preview_companion.mjs",
                }
                for name in names
            ),
            names,
        )


if __name__ == "__main__":
    unittest.main()
