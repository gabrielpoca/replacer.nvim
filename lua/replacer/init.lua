local api = vim.api

local replacer = {}
local buffer_items = {}

local function basename(path)
  chunks = vim.fn.split(path, "/")
  size = vim.tbl_count(chunks)

  if size == 1 then
    return nil
  end

  return vim.fn.join(vim.fn.remove(chunks, 0, -2), "/")
end

function table.empty(self)
  for _, _ in pairs(self) do
    return false
  end

  return true
end

function replacer.run(opts)
  local opts = opts or {}
  local rename_files =  true

  if opts['rename_files'] ~= nil and opts['rename_files'] == false then
    rename_files = false
  end

  local bufnr = vim.fn.bufnr()

  if vim.api.nvim_buf_get_option(vim.fn.bufnr(), "filetype") ~= "qf" then
    vim.api.nvim_command(":echoe 'Current buffer is not a quickfix list'")
    return
  end

  local items = vim.fn.getqflist()

  buffer_items[bufnr] = items

  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

  for i, item in pairs(items) do
    local line = vim.fn.bufname(item.bufnr) .. ':' .. item.text
    vim.api.nvim_buf_set_lines(bufnr, i - 1, i - 1, false, {line})
  end

  local write_autocmd = string.format('autocmd BufWriteCmd <buffer=%s> lua require"replacer".save(%s, { rename_files = %s })', bufnr, bufnr, rename_files)

  vim.api.nvim_command(write_autocmd)

  vim.cmd('setlocal nocursorcolumn nonumber norelativenumber')
  api.nvim_buf_set_name(bufnr, 'replacer://' .. bufnr)
  api.nvim_buf_set_option(bufnr, 'buftype', 'acwrite')
  api.nvim_buf_set_option(bufnr, 'filetype', 'replacer')
  api.nvim_buf_set_option(qf_bufnr, "modified", false)
end

function replacer.save(qf_bufnr, opts)
  local rename_files = opts['rename_files']

  local qf_win_nr = vim.fn.bufwinid(qf_bufnr)

  vim.api.nvim_buf_set_option(qf_bufnr, "modified", false)

  local original_items = buffer_items[qf_bufnr]
  local changed_items = vim.api.nvim_buf_get_lines(qf_bufnr, 0, vim.tbl_count(original_items), false)
  local unique_files = {}

  -- get every unique file
  for _index, item in pairs(original_items) do
    unique_files[vim.fn.bufname(item.bufnr)] = true
  end

  -- for every file
  for current_file in pairs(unique_files) do
    local lines = vim.fn.readfile(current_file)

    -- save changes to each file's contents
    for index, item in pairs(original_items) do
      local file = vim.fn.bufname(item.bufnr)

      if current_file ~= file then
        goto skip_to_next_file
      end

      local current_line = lines[item.lnum]
      local line

      for part, match in pairs(vim.fn.split(changed_items[index], ":", 1)) do
        if part == 1 then
          goto skip_to_next_part
        end

        if line == nil then
          line = match
        else
          line = line .. ":" .. match
        end

        ::skip_to_next_part::
      end

      if current_line ~= line then
        lines[item.lnum] = line
      end

      ::skip_to_next_file::
    end

    vim.fn.writefile(lines, current_file, "S")
  end

  -- move/rename files
  if rename_files then
    for index, item in pairs(original_items) do
      local source_win_id = vim.fn.bufwinid(item.bufnr)
      local source_is_loaded = vim.api.nvim_buf_is_loaded(item.bufnr)
      local source_file = vim.fn.bufname(item.bufnr)
      local source_folder = basename(source_file)

      local dest_file

      -- find the destination file name
      for part, match in pairs(vim.fn.split(changed_items[index], ":")) do
        if part == 1 then
          dest_file = match
        end
      end

      -- reload source buffer
      vim.api.nvim_buf_call(item.bufnr, function()
        vim.cmd("edit!")
      end)

      if source_file ~= "" and source_file ~= dest_file and vim.fn.filereadable(source_file) and vim.fn.filereadable(dest_file) == 0 then
        local dest_folder = vim.fn.mkdir(basename(dest_file), "p")

        -- delete open buffer that's not visible
        if source_is_loaded and source_win_id == -1 then
          vim.api.nvim_buf_delete(item.bufnr, {})
        end

        vim.fn.rename(source_file, dest_file)

        -- update visible buffer to point to the new file
        if source_win_id ~= -1 then
          vim.api.nvim_set_current_win(source_win_id)

          vim.api.nvim_command("edit! " .. dest_file)

          vim.api.nvim_buf_delete(item.bufnr, {})
        end

        -- delete previous folder if empty
        if table.empty(vim.fn.readdir(source_folder)) then
          vim.fn.delete(source_folder, "d")
        end
      end
    end
  end

  vim.api.nvim_set_current_win(qf_win_nr)
end

return replacer;
