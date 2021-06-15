# replacer.nvim

replacer.nvim makes a quickfix window editable, allowing changes to both
the content of a file as well as its path. You can use this to rename
files or move them around. When moving a file around, if the origin folder
gets empty, it's deleted.

See the example below.

![Demo](./demo.gif)

## Using the plugin

First, populate a quickfix window with the lines and files you want to
change. If you don't know how, try the `:Rg` command from [fzf.vim](https://github.com/junegunn/fzf.vim).

Now execute `:lua require("replacer").run()<cr>`. You can also map it to a shortcut, for instance
in lua:

```lua
api.nvim_set_keymap('n', '<Leader>h', ':lua require("replacer").run()<cr>', { silent = true })
```

Or in VimScript:

```
nmap <leader>h :lua require("replacer").run()<cr>
```

Your quickfix window will change and now you can edit the lines and
move/rename the files.

Save the buffer when you're done. That's it.

## Installation

### [vim-plug](https://github.com/junegunn/vim-plug#readme)

add this line to `.vimrc`

```
Plug 'gabrielpoca/replacer.nvim'
```

```lua
api.nvim_set_keymap('n', '<Leader>h', ':lua require("replacer").run()<cr>', { nowait = true, noremap = true, silent = true })
```
