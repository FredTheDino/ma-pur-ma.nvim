#!/usr/bin/env bash
nvim src.purs \
  --headless \
  -c "norm 12ggw" \
  -c "lua require'ma-pur-ma'.extract_to_function()" \
  -c "saveas! gen.purs" \
  -c "q"
