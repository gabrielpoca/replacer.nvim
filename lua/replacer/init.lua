local window = require('replacer.window')
local api = vim.api

local replacer = {}
local buffer_items = {}

local function table_size(t)
  local max = 0

  for i, _ in pairs(t) do
    if i > max then
      max = i
    end
  end

  return max
end

local function basename(path)
  chunks = vim.fn.split(path, "/")
  size = table_size(chunks)

  if size == 1 then
    return nil
  end

  return vim.fn.join(vim.fn.remove(chunks, 0, -2), "/")
end

function replacer.run()
  local bufnr = vim.api.nvim_create_buf(false, true)
  local items = vim.fn.getqflist()

  buffer_items[bufnr] = items

  for i, item in pairs(items) do
    local line = vim.fn.bufname(item.bufnr) .. ':' .. item.text
    vim.api.nvim_buf_set_lines(bufnr, i - 1, i - 1, false, {line})
  end

  window.new(bufnr, table_size(items))
end

function replacer.save(bufnr)
  vim.api.nvim_buf_set_option(bufnr, "modified", false)

  local items = buffer_items[bufnr]
  local quickfix_items = vim.api.nvim_buf_get_lines(bufnr, 0, table_size(items), false)

  -- save changes to each file's contents
  for index, item in pairs(items) do
    local line

    for part, match in pairs(vim.fn.split(quickfix_items[index], ":")) do
      if part == 1 then
        goto skip_to_next
      end

      if line == nil then
        line = match
      else
        line = line .. ":" .. match
      end

      ::skip_to_next::
    end

    local file = vim.fn.bufname(item.bufnr)
    local lines = vim.fn.readfile(file)
    local current_line = lines[item.lnum]

    if current_line ~= line then
      lines[item.lnum] = line
      vim.fn.writefile(lines, file)
    end
  end

  -- move/rename files
  for index, item in pairs(items) do
    local new_file

    for part, match in pairs(vim.fn.split(quickfix_items[index], ":")) do
      if part == 1 then
        new_file = match
      end
    end

    local file = vim.fn.bufname(item.bufnr)

    if file ~= new_file and vim.fn.filereadable(file) and vim.fn.filereadable(new_file) == 0 then
      vim.fn.mkdir(basename(new_file), "p")
      vim.api.nvim_buf_delete(item.bufnr, {})
      vim.fn.rename(file, new_file)
    else
      print("Could not rename " .. unpack(file) .. " to " .. unpack(new_file))
    end
  end
end

return replacer;
