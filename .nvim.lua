-- Project-local Elm LSP; nvim-lspconfig finds frontend/elm.json as the root.
-- Install elm-language-server and elm-format through :Mason.
vim.lsp.config("elmls", {
  cmd = { "elm-language-server" },
})
vim.lsp.enable("elmls")
