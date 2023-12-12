local ts_utils = require("nvim-treesitter.ts_utils")
local locals = require("nvim-treesitter.locals")
local M = {}

local function spy(x)
  print(vim.inspect(x))
end

local function bandaid_largest_node(node)
  -- This is a bandaid for the silly syntaxxtree treesiter produces
  if node:type() == "exp_in" then
    return bandaid_largest_node(get_child(node, 2))
  elseif node:type() == "exp_let" then
    return bandaid_largest_node(node:parent())
  elseif node:type() == "decls" then
    return bandaid_largest_node(find_first_child_of_type("function"), node)
  elseif node:type() == "function" then
    local c
    for n in node:iter_children() do
      if n:named() then
        c = n
      end
    end
    return bandaid_largest_node(c or node:parent())
  else
    return node
  end
end

local function get_first_parent_node_of_type(ty)
  local node = ts_utils.get_node_at_cursor()
  while (node ~= nil
         and node:type() ~= ty) do
    node = node:parent()
  end

  return node
end

local function get_top_node_of_type(ty, node)
  local node = node or ts_utils.get_node_at_cursor()
  local best
  while (node ~= nil) do
    while (node ~= nil and node:type() ~= ty) do
      node = node:parent()
    end
    if node then
      best = node
      node = node:parent()
    end
  end

  return best
end


local function get_top_node(node)
  while (node:parent() ~= node:root()) do
    node = node:parent()
  end
  return node
end

local get_text_at_node = vim.treesitter.get_node_text

local function indent(ii)
  if ii == 0 then
    return ""
  else
    return indent(ii - 1) .. " "
  end
end

local function strip_whitespace(ii, str)
  return string.gsub(str, "^" .. ("%s"):rep(ii) .. "(.-)$", "%1")
end

function find_first_child_of_type(node, ty)
  for n in node:iter_children() do
    if n:type() == ty then
      return n
    end
  end
end

function get_child(node, i)
  local ii = 1
  for n in node:iter_children() do
    if ii == i then return n end
    ii = ii + 1
  end
end

local function shallowcopy(orig)
    if type(orig) == 'table' then
        local copy = {}
        for k, v in pairs(orig) do copy[k] = v end
        return copy
    else
        return orig
    end
end

local function new_scope(locals)
  return shallowcopy(locals)
end

local function find_local(locals, needle)
  for i=#locals, 1, -1 do
    if locals[i].decl == needle or locals[i].name == needle then
      return locals[i]
    end
  end
  return nil
end

local function add_usage(locals, usage, bufnr)
  local name = get_text_at_node(usage, bufnr)
  local loc = find_local(locals, name)
  if loc then
    table.insert(loc.usages, usage)
  else
    -- has to be global :shrug:
  end
end

local function define_local(locals, decl, bufnr)
  local name = get_text_at_node(decl, bufnr)
  table.insert(locals, { name = name, decl = decl, usages = {}})
end

local function type_and_ptype_is(node, ty, pty)
  return node:type() == ty
     and node:parent()
     and node:parent():type() == pty
end

-- locals :: [ (Usages, Decl, Name) ]
-- Finds all used variables (not `true` or `false`) and all definitions 
local function find_usages_and_definitions_at(at, locals, final, bufnr)
  if at == final then return true, locals end

  -- Not everything in the tree is a node - there are other things
  local status, err = pcall(function() at:type() end)
  if not status then return false, locals end

  if type_and_ptype_is(at, "variable", "pat_name")
  or type_and_ptype_is(at, "variable", "pat_as")
  or type_and_ptype_is(at, "variable", "function")
  or (   type_and_ptype_is(at, "field_name", "pat_field")
     and nil == find_first_child_of_type(at:parent(), "pat_name")
     )
  then
    define_local(locals, at, bufnr)
    return false, locals

  elseif at:type() == "variable" or at:type() == "exp_name"  then
    add_usage(locals, at, bufnr)
    return false, locals

  elseif at:type() == "exp_let_in" then
    local inner_locals = new_scope(locals)
    local let_ = find_first_child_of_type(at, "exp_let")
    if let_ == final then return true end
    local decls_ = find_first_child_of_type(let_, "decls")
    for c in decls_:iter_children() do
      local done, ret = find_usages_and_definitions_at(c, inner_locals, final, bufnr)
      if done then return done, ret end
    end

    local in_ = find_first_child_of_type(at, "exp_in")
    return find_usages_and_definitions_at(in_, inner_locals, final, bufnr)

  elseif at:type() == "function" then
    define_local(locals, find_first_child_of_type(at, "variable"), bufnr)

    local inner_locals = new_scope(locals)
    local patterns_ = find_first_child_of_type(at, "patterns")
    if patterns_ ~= nil then
      for c in patterns_:iter_children() do
        local done, ret = find_usages_and_definitions_at(c, inner_locals, final, bufnr)
        if done then return done, ret end
      end
    end

    local decls_ = find_first_child_of_type(at, "decls")
    if decls_ then
      for c in decls_:iter_children() do
        local done, ret = find_usages_and_definitions_at(c, inner_locals, final, bufnr)
        if done then return done, ret end
      end
    end

    -- NOTE[et]: c:named("") does not work and checks if the node is named
    -- NOTE[et]: at:field("") does not pick out the actual "child node" it picks out something else and I don't know what.
    local rhs_ = nil
    for c in at:iter_children() do
      rhs_ = c
    end
    if rhs_ then
      return find_usages_and_definitions_at(rhs_, inner_locals, final, bufnr)
    else
      return false, inner_locals
    end

  else
    for c in at:iter_children() do
      local done, ret = find_usages_and_definitions_at(c, locals, final, bufnr)
      if done then return done, ret end
    end

    return false, locals
  end
end

function M.extract_to_function() 
  local bufnr = vim.api.nvim_get_current_buf()
  local node = get_top_node_of_type("function")

  local at
  if vim.api.nvim_get_mode().mode:lower():find("v") then
    local at0 = ts_utils.get_node_at_cursor()
    vim.cmd.normal("o")
    local at1 = ts_utils.get_node_at_cursor()
    vim.api.nvim_input("<ESC>")
    print(at0, at1)
    at = at0
    while at and not (vim.treesitter.is_ancestor(at, at0) and vim.treesitter.is_ancestor(at, at1)) do
      at = at:parent()
    end
    if at == nil then
      exit("Couldn't find a node for the range")
    end
  else
    at = bandaid_largest_node(ts_utils.get_node_at_cursor())
  end
  local _, outer = find_usages_and_definitions_at(node, {}, at, bufnr)
  local _, inner = find_usages_and_definitions_at(at, new_scope(outer), nil, bufnr)

  f_new = "extracted"
  for _, def in pairs(inner) do
    local is_defined_outside = not vim.treesitter.is_ancestor(at, def.definition)
    local is_used_inside = false
    for _, u in pairs(def.usages) do
      if vim.treesitter.is_ancestor(at, u) then
        is_used_inside = true
        break
      end
    end
    if is_defined_outside and is_used_inside then
      f_new = f_new .. " " .. def.name
    end
  end

  local def = { "", f_new .. " ="}
  local s = get_text_at_node(at, bufnr)
  for v in s:gmatch("[^\r\n]+") do
    table.insert(def, indent(2) .. v)
  end

  local start_row, start_col, end_row, end_col = at:range()
  vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { "(" .. f_new .. ")" })

  local _, _, end_row, _ = node:range()
  vim.api.nvim_buf_set_lines(bufnr, end_row + 1, end_row + 1, false, def)
end

-- TODO[et]: Remove sometime
function M.toggle_import() 
  M.toggle_export()
end

function M.toggle_export() 
  local bufnr = vim.api.nvim_get_current_buf()

  local to_export
  local p = get_top_node_of_type("function")
  if p then
    local f = find_first_child_of_type(p, "variable")
    to_export = get_text_at_node(f, bufnr)
  end
  local p = get_top_node_of_type("data")
  if p then
    local f = find_first_child_of_type(p, "type")
    to_export = get_text_at_node(f, bufnr) .. "(..)"
  end
  local p = get_top_node_of_type("type_alias")
  if p then
    local f = find_first_child_of_type(p, "type"):next_sibling()
    to_export = get_text_at_node(f, bufnr)
  end
  local p = get_top_node_of_type("newtype")
  if p then
    local f = find_first_child_of_type(p, "type")
    to_export = get_text_at_node(f, bufnr) .. "(..)"
  end
  local p = get_top_node_of_type("class_declaration")
  if p then
    local f = find_first_child_of_type(p, "class_head")
    local g = find_first_child_of_type(f, "class_name")
    to_export = "class " .. get_text_at_node(g, bufnr)
  end

  if not to_export then
    return
  end

  local root = ts_utils.get_node_at_cursor():root()
  local exports = find_first_child_of_type(root, "exports")

  local exports_start = exports:range()
  local is_multiline = false
  local num_exports = 0
  local export
  local _, l = exports:range()
  for c in exports:iter_children() do
    if c:type() == "export"
    and get_text_at_node(c, bufnr) ~= "("
    and get_text_at_node(c, bufnr) ~= ")"
    and get_text_at_node(c, bufnr) ~= ""
    then
      num_exports = num_exports + 1
    end
    if c:type() == "export"
    and get_text_at_node(c, bufnr) == to_export
    then
      export = c
    end  
    local export_line = c:range()
    if l ~= export_line then
      is_multiline = true
    end
  end

  if export then
    local start_row, start_col, end_row, end_col = export:range()
    if export:prev_sibling():type() == "comma" then
      local comma_row, comma_col = export:prev_sibling():range()
      start_row = comma_row
      start_col = comma_col
    elseif export:next_sibling():type() == "comma" then
      local comma_row, comma_col = export:next_sibling():range()
      end_row = comma_row
      end_col = comma_col + 2
    end
    vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, {})
  else
    local start_row, start_col, end_row, end_col = exports:range()
    local maybe_with_comma = to_export
    if num_exports == 0 then
      vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, { "(" .. to_export .. ")" })
    else
      if is_multiline then
        vim.api.nvim_buf_set_text(bufnr, start_row, start_col + 1, start_row, start_col + 1, { " " .. to_export, "  ," })
      else
        vim.api.nvim_buf_set_text(bufnr, start_row, start_col + 1, start_row, start_col + 1, { to_export .. "," })
      end
    end
  end
end

function M.if_to_case() 
  local bufnr = vim.api.nvim_get_current_buf()
  local if_node = get_first_parent_node_of_type("exp_if")


  if if_node == nil then
    error("Couldn't find a if expression")
  end

  local children = {}
  local i = 1
  for c in if_node:iter_children() do
    children[i] = get_text_at_node(c, bufnr)
    i = i + 1
  end
  local condition = children[2]
  local true_branch = children[4]
  local false_branch = children[6]

  if condition == true_branch and true_branch == false_branch then
    error("Tree sitter isn't updating")
  end

  local start_row, start_col, end_row, end_col = if_node:range()
  vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col,
      { "case " .. condition .. " of"
      , indent(start_col + 2) .. "true -> " .. true_branch
      , indent(start_col + 2) .. "false -> " .. false_branch 
      }
  )
end

function M.fill_in_data_case() 
  local bufnr = vim.api.nvim_get_current_buf()
  local node = ts_utils.get_node_at_cursor()
  local node_text = get_text_at_node(node, bufnr)
  local root = node:root()

  local constructors = {}
  for c in root:iter_children() do
    if c:type() == "data" 
      and node_text == get_text_at_node(c:named_child("name"), bufnr)
    then
      found_data = true
      -- This is the matching one
      for d in c:iter_children() do
        local text = get_text_at_node(d, bufnr)
        if text ~= "|" then
          if d:type() == "constructor" then
            table.insert(constructors, { text })
          elseif #constructors ~= 0 then
            table.insert(constructors[#constructors], text)
          end
        end
      end
      break
    end
  end

  if #constructors == 0 then
    error("Couldn't find constructors")
  end

  local start_row, start_col, end_row, end_col = node:range()
  local replacements = { "case _ of" }
  for _, c in pairs(constructors) do
    local text = indent(start_col + 2)
    for _, d in pairs(c) do
      text = text .. d .. " "
    end
    text = text .. "-> no"
    table.insert(replacements, text)
  end
  vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, replacements)
end
--
-- inline function

return M
