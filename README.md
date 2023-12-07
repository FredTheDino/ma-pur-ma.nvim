# Ma Pur Ma or (Macros, Purs Macros)
The LSP in PureScript has some (according to me) missing features. Thankfully
we have a tree-sitter parser now which means we can easily parse the entire
Purs file to resolve variables and understand the semantics.

All the macros in this project are implemented using the neovim tree-sitter
plugin and requires a specific version of the tree-sitter parser to work,
breakages may occurs if you change the tree-sitter parser from
[the currently best PureScript tree-sitter parser](https://github.com/postsolar/tree-sitter-purescript).

Install this plugin - like you would any other:
```

```

