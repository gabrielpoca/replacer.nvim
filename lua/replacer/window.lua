local api = vim.api
local window = {}

local function create_border(win_opts)
  local border_opts = {
    style = "minimal",
    relative = "editor",
    row = win_opts.row - 1,
    col = win_opts.col - 1,
    width = win_opts.width + 2,
    height = win_opts.height + 2,
  }

  -- starts with top border
  local border_lines = {'╭' .. string.rep('─', win_opts.width) .. '╮'}

  -- adds left and right borders
  local middle_line = '│' .. string.rep(' ', win_opts.width) .. '│'

  for i = 1, win_opts.height do
    table.insert(border_lines, middle_line)
  end

  -- adds bottom border
  table.insert(border_lines, '╰' .. string.rep('─', win_opts.width) .. '╯')

  local border_buffer = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(border_buffer, 0, -1, true, border_lines)
  local border_window = api.nvim_open_win(border_buffer, true, border_opts)
  vim.cmd 'set winhl=Normal:Floating'

  return border_buffer
end

function window.new(bufnr, nr_of_lines)
  local width = vim.api.nvim_get_option("columns")
  local height = vim.api.nvim_get_option("lines")

  local win_height = math.ceil(height * 3 / 4)
  local win_width = math.ceil(width * 0.9)

  if (width < 150) then
    win_width = math.ceil(width - 8)
  end

  if (nr_of_lines < win_height) then
    win_height = nr_of_lines
  end

  local row = math.ceil((height - win_height) / 2)
  local col = math.ceil((width - win_width) / 2)

  local opts = {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
  }

  local border_buffer = create_border(opts)
  local win = vim.api.nvim_open_win(bufnr, true, opts)

  -- closes window on leave
  vim.cmd('au WinLeave <buffer> :close')

  -- ensure that the border_window closes at the same time
  local cmd = [[autocmd WinLeave <buffer> silent! execute 'silent bdelete %s']]
  vim.cmd(cmd:format(border_buffer))

  -- on save call the save function
  local write_autocmd = string.format('autocmd BufWriteCmd <buffer=%s> lua require"replacer".save(%s)', bufnr, bufnr)
  vim.api.nvim_command(write_autocmd)

  vim.cmd('setlocal nocursorcolumn nonumber norelativenumber')
  api.nvim_buf_set_name(bufnr, 'replacer://' .. bufnr)
  api.nvim_buf_set_option(bufnr, 'buftype', 'acwrite')
  api.nvim_buf_set_option(bufnr, 'filetype', 'replacer')
  vim.api.nvim_win_set_cursor(win, {1, 1})
  vim.api.nvim_buf_set_option(bufnr, "modified", false)
end

return window;
