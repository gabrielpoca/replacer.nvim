# replacer.nvim

It makes a quickfix list editable. Unlike most other similar plugins, you
can also rename files. With this, you can easily perform a find/replace
across your files, changing not just each file's contents but the file
names as well.

## Using the plugin

Populate a quickfix list and execute `:lua require("replacer").run()<cr>`.
You can map it to a shortcut, for instance in lua:

```lua
api.nvim_set_keymap('n', '<Leader>h', ':lua require("replacer").run()<cr>', { silent = true })
```

Or in VimScript:

```
nmap <leader>h :lua require("replacer").run()<cr>
```

When you're done editing the buffer save it and it's done.

## Installation

### [vim-plug](https://github.com/junegunn/vim-plug#readme)

add this line to `.vimrc`

```
Plug 'gabrielpoca/replacer.nvim'
```

```lua
api.nvim_set_keymap('n', '<Leader>h', ':lua require("replacer").run()<cr>', { nowait = true, noremap = true, silent = true })
```
