# replacer.nvim

replacer.nvim makes quickfix windows editable, allowing changes to both the
content of a file and its path. You can use this to rename variables and files
easily. When moving a file around, if the origin folder gets empty, it's
deleted.

See the example below.

![Demo](./demo.gif)

## Using the plugin

First, populate a quickfix window with the lines and files you want to
change. If you don't know how, try the `:Rg` command from [fzf.vim](https://github.com/junegunn/fzf.vim).

Now, inside the quickfix window, execute `:lua require("replacer").run()<cr>`.
You can also map it to a shortcut, for instance in lua:

```lua
api.nvim_set_keymap('n', '<leader>h', ':lua require("replacer").run()<cr>', { silent = true })
```

Or in VimScript:

```
nmap <leader>h :lua require("replacer").run()<cr>
```

Your quickfix window will change and now you can edit the lines and
move/rename the files.

Save the buffer when you're done. That's it.

### Renaming files

Renaming/moving files is enabled by default. To disable this functionality, set
the option `rename_files`. For instance:

```lua
api.nvim_set_keymap('n', '<Leader>h', ':lua require("replacer").run({ rename_files = false })<cr>', { silent = true })
```

### Saving the changes

By default, changes are saved when you write the buffer. To disable this
functionality and instead set a custom shortcut to save the changes, set the
`save_on_write` option and execute the `save` function. For instance:

```lua
local opts = { save_on_write = false, rename_files = false }

api.nvim_set_keymap('n', '<Leader>h', ':lua require("replacer").run(opts)<cr>', { silent = true })

api.nvim_set_keymap('n', '<Leader>H', ':lua require("replacer").save(opts)<cr>', { silent = true })
```

Notice that the options are sent to both `run` and `save`. This is important
for consistent behavior.

### Global options

You can also use the `setup` function to set global options. For instance, with
lazy.nvim you can do something like this:

```lua
{
    dir = 'gabrielpoca/replacer.nvim',
    opts = {rename_files = false},
    keys = {
        {
            '<leader>h',
            function() require('replacer').run() end,
            desc = "run replacer.nvim"
        }
    }
}
```

The `rename_files` will be set to `false` by default in every execution
of the functions `run` and `save`.
