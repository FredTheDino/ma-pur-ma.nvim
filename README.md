# Ma Pur Ma or (Macros, Purs Macros)
The LSP in PureScript has some (according to me) missing features. Thankfully
we have a tree-sitter parser now which means we can easily parse the entire
Purs file to resolve variables and understand the semantics.

All the macros in this project are implemented using the neovim tree-sitter
plugin and requires a specific version of the tree-sitter parser to work,
breakages may occurs if you change the tree-sitter parser from
[the currently best PureScript tree-sitter parser](https://github.com/postsolar/tree-sitter-purescript).

Install this plugin - like you would any other with e.g. `Plug`
```
    Plug("FredTheDino/ma-pur-ma.nvim")
```

Then you will want to define some mappings for the operations this plugin allows. NOTE: No bindings are setup automatically.

```
local mpm = require "ma-pur-ma"
vim.keymap.set('n', '<SPACE>pe', mpm.extract_to_function)
vim.keymap.set('n', '<SPACE>pi', mpm.toggle_import)
vim.keymap.set('n', '<SPACE>pf', mpm.if_to_case)
vim.keymap.set('n', '<SPACE>pc', mpm.fill_in_data_case)
```


