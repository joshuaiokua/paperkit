-- refs.lua — make a milestone PDF's references actually work.
--
--   1. Inline bracketed citation markers [N] become internal links to the
--      matching bibliography entry (anchored ref-N).
--   2. Bullet-list items that BEGIN with [N] (the bibliography) get the ref-N
--      anchor. The marker inside the entry self-links — harmless.
--   3. Relative links to sibling .md files (run-report cross-links) are
--      unlinked: a PDF cannot resolve them, so their text stays as plain text.
--      The markdown source keeps the real links for GitHub.
--
-- Bare URLs are made clickable by `+autolink_bare_uris` in the pandoc
-- invocation (render.sh / the installed workflows), not by this filter.
-- If a [N] has no matching bibliography anchor, typst fails the render loudly
-- (unknown label) — that is a feature: a dangling reference is a report bug.

-- Runs after the element filters: promote a lone leading H1 to the document
-- title when the source has no front-matter title. The markdown keeps its H1
-- for GitHub; the PDF gets real /Title metadata (house.typ's conf feeds it to
-- `set document`) and re-renders the title through the same level-1 heading
-- path, so outline/bookmarks and heading hierarchy stay intact.
function Pandoc(doc)
  if doc.meta.title == nil then
    for i, b in ipairs(doc.blocks) do
      if b.t == "Header" and b.level == 1 then
        doc.meta.title = pandoc.MetaInlines(b.content)
        table.remove(doc.blocks, i)
        break
      end
    end
  end
  return doc
end

local function leading_ref(inl)
  if inl == nil then return nil end
  if inl.t == "Str" then
    return inl.text:match("^%[(%d+)%]$")
  end
  -- After the Str pass, the bibliography's own leading [N] is already a Link.
  if inl.t == "Link" and #inl.content == 1 and inl.content[1].t == "Str" then
    return inl.content[1].text:match("^%[(%d+)%]$")
  end
  return nil
end

local anchored = {}

function BulletList(el)
  for _, item in ipairs(el.content) do
    local first = item[1]
    if first and (first.t == "Plain" or first.t == "Para") then
      local n = leading_ref(first.content[1])
      if n and not anchored[n] then
        anchored[n] = true
        first.content[1] = pandoc.Span({first.content[1]}, {id = "ref-" .. n})
      end
    end
  end
  return el
end

function Str(el)
  if not el.text:find("%[%d+%]") then
    return nil
  end
  local out = pandoc.Inlines({})
  local pos = 1
  while true do
    local s, e, n = el.text:find("%[(%d+)%]", pos)
    if not s then break end
    if s > pos then
      out:insert(pandoc.Str(el.text:sub(pos, s - 1)))
    end
    out:insert(pandoc.Link({pandoc.Str("[" .. n .. "]")}, "#ref-" .. n))
    pos = e + 1
  end
  if pos <= #el.text then
    out:insert(pandoc.Str(el.text:sub(pos)))
  end
  return out
end

function Link(el)
  local t = el.target
  local is_external = t:match("^%a[%w+.-]*:") ~= nil   -- has a URI scheme
  local is_internal = t:sub(1, 1) == "#"
  if not is_external and not is_internal and t:match("%.md$") then
    return el.content
  end
  return nil
end
