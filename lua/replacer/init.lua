local autocmd = vim.api.nvim_create_autocmd
local api = vim.api

local M = {}

local global_opts = {rename_files = true, save_on_write = true}

local function basename(path)
    local chunks = vim.fn.split(path, "/")
    local size = vim.tbl_count(chunks)

    if size == 1 then return nil end

    table.remove(chunks)

    return table.concat(chunks, "/")
end

local function delete_empty_folder(file)
    local folder = basename(file)
    if vim.tbl_isempty(vim.fn.readdir(folder)) then
        vim.fn.delete(folder, "d")
    end
end

local function cleanup(bufnr)
    api.nvim_buf_delete(bufnr, {force = true})
    -- cleanup qf list
    vim.fn.setqflist({}, "r")
    -- reload current file
    if vim.fn.bufname() ~= "" then vim.cmd('edit') end
end

function M.save(opts)
    local qf_bufnr = vim.fn.bufnr()
    local qf_items = vim.fn.getqflist()

    local rename_files = opts['rename_files']

    vim.bo[qf_bufnr].modified = false

    local changed_items = api.nvim_buf_get_lines(qf_bufnr, 0,
                                                 vim.tbl_count(qf_items), false)
    local unique_files = {}

    -- get every unique file
    for _, item in pairs(qf_items) do
        unique_files[vim.fn.bufname(item.bufnr)] = true
    end

    -- for every file
    for current_file in pairs(unique_files) do
        local lines = vim.fn.readfile(current_file)

        -- save changes to each file's contents
        for index, item in pairs(qf_items) do
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
            vim.notify(string.format('Something went wrong writing file %s',
                                     current_file), vim.log.levels.ERROR)
            cleanup(qf_bufnr)
            return
        end
    end

    local renamed_files = {}

    -- move/rename files
    if rename_files then
        for index, item in pairs(qf_items) do
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

                -- delete open buffer that's not visible
                if source_is_loaded and source_win_id == -1 then
                    api.nvim_buf_delete(item.bufnr, {})
                end

                -- ensure destination directory exists
                vim.fn.mkdir(basename(dest_file), "p")

                ---@diagnostic disable-next-line: param-type-mismatch wrong annotation information when using neodeiv + lua-lsp
                local exitCode = vim.fn.rename(source_file, dest_file)
                if exitCode ~= 0 then
                    local msg = string.format('Failed to rename %s to %s',
                                              source_file, dest_file)
                    vim.notify(msg, vim.log.levels.ERROR)
                    goto skip_to_next_file
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

    cleanup(qf_bufnr)
end

function M.setup(opts)
    global_opts = vim.fn.extend(global_opts, opts or global_opts, "force")
end

function M.run(opts)
    if #vim.fn.getqflist() == 0 then
        vim.notify('Quickfix List empty.', vim.log.levels.WARN)
        return
    end

    opts = vim.fn.extend(global_opts, opts or global_opts, "force")

    -- open quickfix list, if it is not open
    if vim.bo.filetype ~= "qf" then vim.cmd.copen() end

    local qf_items = vim.fn.getqflist()

    vim.bo.modifiable = true

    api.nvim_buf_set_lines(0, 0, -1, false, {})

    for i, item in pairs(qf_items) do
        if not api.nvim_buf_is_loaded(item.bufnr) then
            vim.fn.bufload(item.bufnr)
        end

        local text = api.nvim_buf_get_lines(item.bufnr, item.lnum - 1,
                                            item.lnum, false)[1]

        local line = vim.fn.bufname(item.bufnr) .. ':' .. text

        api.nvim_buf_set_lines(0, i - 1, i - 1, false, {line})
    end

    if opts.save_on_write then
        local qf_bufnr = vim.fn.bufnr()

        autocmd('BufWriteCmd', {
            buffer = qf_bufnr,
            once = true,
            callback = function() M.save(opts) end
        })

        vim.bo.buftype = 'acwrite'
    else
        vim.bo.buftype = 'nofile'
    end

    api.nvim_buf_set_name(0, 'replacer://replacer')
    api.nvim_win_set_cursor(0, {1, 0})

    vim.opt_local.cursorcolumn = false
    vim.opt_local.number = false
    vim.opt_local.wrap = false
    vim.opt_local.relativenumber = false
    vim.opt_local.number = false
    vim.bo.filetype = 'replacer'
    vim.bo.formatoptions = '' -- to not autowrap lines, breaking filenames
end

return M;
