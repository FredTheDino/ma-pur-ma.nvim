# Ma Pur Ma or (Macros, Purs Macros)
(2023-12-07: This is a work in progress, it might be buggy, I appreciate all feedback I can get)

The LSP in PureScript has some (according to me) missing features. Thankfully
we have a tree-sitter parser now which means we can easily parse the entire
Purs file to resolve variables and understand the semantics.

All the macros in this project are implemented using the neovim tree-sitter
plugin and requires a specific version of the tree-sitter parser to work,
breakages may occurs if you change the tree-sitter parser from
[the currently best PureScript tree-sitter parser](https://github.com/postsolar/tree-sitter-purescript).

## Getting Started
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

## Bugs
This code is probably buggy, if you find a piece of code this doesn't work on, show it to me. I know of some problems with the `extract_to_function` but it is good to see how often issues appear aswell.

Make an issue with the code and what you expect to happen, and I'll get to i when I get to it. :)

You need to enable the [tree-sitter highlighter](https://github.com/nvim-treesitter/playground/issues/64) for this plugin to work properly - I know no other way around this.
```
TSEnable highlight
```


## Things to do
 - [ ] Would be great with some unit tests for this - should be easily doable with `nvim --cmd`
 - [ ] `inline_function` would be great
 - [ ] `a $ b` -> `b # a` might be real nice
