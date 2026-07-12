-- refs.lua — normalize paper metadata and preserve legacy reference behavior.
--
--   1. The resolved title and keyword list become invisible labeled Typst
--      metadata for the house template's running furniture and title matter.
--   2. Inline bracketed citation markers [N] become internal links to the
--      matching bibliography entry (anchored ref-N).
--   3. Bullet-list items that BEGIN with [N] (the bibliography) get the ref-N
--      anchor. The marker inside the entry self-links — harmless.
--   4. Relative links to sibling .md files (run-report cross-links) are
--      unlinked: a PDF cannot resolve them, so their text stays as plain text.
--      The markdown source keeps the real links for GitHub.
--
-- Native [@key] citations are deliberately untouched: Pandoc's Typst writer
-- passes them to Typst's bibliography engine. Bare URLs are made clickable by
-- `+autolink_bare_uris` in render.sh, not by this filter.
-- If a [N] has no matching bibliography anchor, typst fails the render loudly
-- (unknown label) — that is a feature: a dangling reference is a report bug.

local MAX_RUNNING_TITLE_BYTES = 64

-- Runs after the element filters: promote a lone leading H1 to the document
-- title when the source has no front-matter title. The markdown keeps its H1
-- for GitHub; the PDF gets real /Title metadata (house.typ's conf feeds it to
-- `set document`) and re-renders the title through the same level-1 heading
-- path, so outline/bookmarks and heading hierarchy stay intact.
local function typst_string(value)
  local escaped = pandoc.utils.stringify(value)
    :gsub("\\", "\\\\")
    :gsub('"', '\\"')
    :gsub("\n", "\\n")
  return '"' .. escaped .. '"'
end

local function insert_typst_metadata(doc, expression, label)
  table.insert(doc.blocks, 1, pandoc.RawBlock(
    "typst",
    "#metadata(" .. expression .. ") <" .. label .. ">"
  ))
end

local function meta_text(meta)
  if meta == nil then return nil end
  local value = pandoc.utils.stringify(meta)
  if value == "" then return nil end
  return value
end

local function iso_date_expression(meta)
  local value = meta_text(meta)
  if value == nil then return nil end
  local year, month, day = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  if year == nil then return nil end
  local year_number = tonumber(year)
  local month_number = tonumber(month)
  local day_number = tonumber(day)
  local month_lengths = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
  if year_number < 1 then return nil end
  if month_number < 1 or month_number > 12 then return nil end
  if year_number % 400 == 0 or (year_number % 4 == 0 and year_number % 100 ~= 0) then
    month_lengths[2] = 29
  end
  if day_number < 1 or day_number > month_lengths[month_number] then return nil end
  return string.format(
    "datetime(year: %d, month: %d, day: %d)",
    year_number, month_number, day_number
  )
end

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

  -- Flatten rich title content so running furniture stays plain and unlinked.
  local running_title = doc.meta["running-title"]
  if running_title == nil and doc.meta.title ~= nil then
    local title_text = meta_text(doc.meta.title)
    if title_text ~= nil and #title_text <= MAX_RUNNING_TITLE_BYTES then
      running_title = doc.meta.title
    else
      running_title = "Research paper"
    end
  end
  if running_title ~= nil then
    insert_typst_metadata(
      doc,
      typst_string(running_title),
      "paperkit-running-title"
    )
  end

  local document_type = meta_text(doc.meta["document-type"])
  if document_type ~= nil then
    insert_typst_metadata(doc, typst_string(document_type), "paperkit-document-type")
  end

  local authored_date = iso_date_expression(doc.meta.date)
  if authored_date ~= nil then
    insert_typst_metadata(doc, authored_date, "paperkit-authored-date")
  end

  local description = meta_text(doc.meta.abstract)
  if description ~= nil then
    insert_typst_metadata(doc, typst_string(description), "paperkit-description")
  end

  -- Pandoc 3.10 emits multiword native keywords as invalid Typst arguments
  -- (`keywords: (research operations,...)`), so serialize them explicitly.
  if doc.meta.keywords ~= nil then
    local keywords = {}
    for _, keyword in ipairs(doc.meta.keywords) do
      table.insert(keywords, typst_string(keyword))
    end
    doc.meta.keywords = nil
    if #keywords > 0 then
      insert_typst_metadata(
        doc,
        "(" .. table.concat(keywords, ", ") .. ")",
        "paperkit-keywords"
      )
    end
  end
  return doc
end

function Span(el)
  if el.classes:includes("focal-value") then
    if el.identifier == "" then
      el.identifier = "paperkit-focal-value"
    else
      el.content = pandoc.Inlines({
        pandoc.Span(el.content, {id = "paperkit-focal-value"})
      })
    end
    el.classes = el.classes:filter(function(class)
      return class ~= "focal-value"
    end)
  end
  return el
end

function Div(el)
  if el.classes:includes("table-note") then
    if el.identifier == "" then
      el.identifier = "paperkit-table-note"
    else
      el.content = pandoc.Blocks({
        pandoc.Div(el.content, {id = "paperkit-table-note"})
      })
    end
    el.classes = el.classes:filter(function(class)
      return class ~= "table-note"
    end)
  end
  return el
end

function Figure(el)
  local block = el.content[1]
  local image = block and block.content and block.content[1]
  if image == nil or image.t ~= "Image" then return nil end

  local explicit_alt = image.attributes["fig-alt"]
  if explicit_alt ~= nil and explicit_alt ~= "" then
    image.caption = pandoc.Inlines({pandoc.Str(explicit_alt)})
  end

  local caption = el.caption.long[1]
  for _, layer in ipairs({
    {label = "Note.", value = image.attributes["fig-note"]},
    {label = "Source.", value = image.attributes["fig-source"]},
  }) do
    if layer.value ~= nil and layer.value ~= "" and caption ~= nil then
      caption.content:insert(pandoc.LineBreak())
      caption.content:insert(pandoc.Strong({pandoc.Str(layer.label)}))
      caption.content:insert(pandoc.Space())
      caption.content:insert(pandoc.Str(layer.value))
    end
  end

  image.attributes["fig-alt"] = nil
  image.attributes["fig-note"] = nil
  image.attributes["fig-source"] = nil
  return el
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
