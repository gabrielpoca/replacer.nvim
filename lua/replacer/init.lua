local autocmd = vim.api.nvim_create_autocmd
local api = vim.api

local replacer = {}
local buffer_items = {}

function basename(path)
    chunks = vim.fn.split(path, "/")
    size = vim.tbl_count(chunks)

    if size == 1 then return nil end

    return vim.fn.join(vim.fn.remove(chunks, 0, -2), "/")
end

function table.empty(self)
    for _, _ in pairs(self) do return false end

    return true
end

function delete_empty_folder(file)
    local folder = basename(file)

    if table.empty(vim.fn.readdir(folder)) then vim.fn.delete(folder, "d") end
end

function cleanup()
    for bufnr, _ in pairs(buffer_items) do
        api.nvim_buf_delete(bufnr, {force = true})
    end

    buffer_items = {}
end

function save(qf_bufnr, opts)
    local rename_files = opts['rename_files']

    local qf_win_nr = vim.fn.bufwinid(qf_bufnr)

    api.nvim_buf_set_option(qf_bufnr, "modified", false)

    local original_items = buffer_items[qf_bufnr]
    local changed_items = api.nvim_buf_get_lines(qf_bufnr, 0,
                                                 vim.tbl_count(original_items),
                                                 false)
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

            if current_file ~= file then goto skip_to_next_file end

            local current_line = lines[item.lnum]
            local line

            for part, match in pairs(vim.fn.split(changed_items[index], ":", 1)) do
                if part == 1 then goto skip_to_next_part end

                if line == nil then
                    line = match
                else
                    line = line .. ":" .. match
                end

                ::skip_to_next_part::
            end

            if current_line ~= line then lines[item.lnum] = line end

            ::skip_to_next_file::
        end

        local result = vim.fn.writefile(lines, current_file, "S")

        if result < 0 then
            error(string.format('Something went wrong writing file %s',
                                current_file))
            cleanup()
            return
        end
    end

    local renamed_files = {}

    -- move/rename files
    if rename_files then
        for index, item in pairs(original_items) do
            local source_win_id = vim.fn.bufwinid(item.bufnr)
            local source_is_loaded = api.nvim_buf_is_loaded(item.bufnr)
            local source_file = vim.fn.bufname(item.bufnr)

            -- already renamed this file
            if renamed_files[item.bufnr] then goto skip_to_next_file end

            local dest_file

            -- find the destination file name
            for part, match in pairs(vim.fn.split(changed_items[index], ":")) do
                if part == 1 then dest_file = match end
            end

            -- if source and destination files are the same
            if source_file == dest_file then goto skip_to_next_file end

            -- if the destination file already exists
            if (vim.fn.filereadable(dest_file)) == 1 then
                error(string.format('File %s already exists', dest_file))

                goto skip_to_next_file
            end

            -- reload source buffer
            api.nvim_buf_call(item.bufnr, function() vim.cmd("edit!") end)

            if source_file ~= "" and vim.fn.filereadable(source_file) then
                renamed_files[item.bufnr] = true

                local dest_folder = vim.fn.mkdir(basename(dest_file), "p")

                -- delete open buffer that's not visible
                if source_is_loaded and source_win_id == -1 then
                    api.nvim_buf_delete(item.bufnr, {})
                end

                if vim.fn.rename(source_file, dest_file) ~= 0 then
                    error(string.format('Failed to rename %s to %s',
                                        source_file, dest_file))
                end

                -- update visible buffer to point to the new file
                if source_win_id ~= -1 then
                    api.nvim_set_current_win(source_win_id)

                    api.nvim_command("edit! " .. dest_file)

                    api.nvim_buf_delete(item.bufnr, {})
                end

                delete_empty_folder(source_file)
            end

            ::skip_to_next_file::
        end
    end

    cleanup()
    return
end

function replacer.run(opts)
    local opts = opts or {}
    local rename_files = true

    if opts['rename_files'] == false then rename_files = false end

    local bufnr = vim.fn.bufnr()

    if api.nvim_buf_get_option(0, "filetype") ~= "qf" then
        error('Current buffer is not a quickfix list')
        return
    end

    local items = vim.fn.getqflist()

    buffer_items[bufnr] = items

    api.nvim_buf_set_option(bufnr, "modifiable", true)
    api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

    for i, item in pairs(items) do
        local line = vim.fn.bufname(item.bufnr) .. ':' .. item.text
        api.nvim_buf_set_lines(bufnr, i - 1, i - 1, false, {line})
    end

    autocmd('BufWriteCmd', {
        buffer = bufnr,
        once = true,
        callback = function() save(bufnr, {rename_files = rename_files}) end
    })

    vim.cmd('setlocal nocursorcolumn nonumber norelativenumber')

    api.nvim_buf_set_name(bufnr,
                          'replacer://' .. vim.tbl_count(buffer_items) + 1)
    api.nvim_buf_set_option(bufnr, 'buftype', 'acwrite')
    api.nvim_buf_set_option(bufnr, 'filetype', 'replacer')
end

return replacer;
