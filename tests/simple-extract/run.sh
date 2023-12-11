#!/usr/bin/env bash
nvim src.purs \
  -c "10" \
  -c "norm w" \
  -c "lua require'ma-pur-ma'.extract_to_function()" \
  -c "saveas! gen.purs" \
  -c "q"

diff --color out.purs gen.purs
