-- Project-local Elm LSP; nvim-lspconfig finds frontend/elm.json as the root.
-- Install elm-language-server and elm-format through :Mason.
vim.lsp.config("elmls", {
  cmd = { "elm-language-server" },
})
vim.lsp.enable("elmls")

vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("urlshortener.elm-format", { clear = true }),
  pattern = "*.elm",
  callback = function(event)
    local formatter = "elm-format"
    if vim.fn.executable(formatter) == 0 then
      formatter = vim.fn.stdpath("data") .. "/mason/bin/elm-format"
    end
    local input = table.concat(vim.api.nvim_buf_get_lines(event.buf, 0, -1, false), "\n") .. "\n"
    local result = vim.system({ formatter, "--stdin", "--elm-version", "0.19" }, {
      stdin = input,
      text = true,
    }):wait(2000)
    if result.code ~= 0 then
      vim.notify("Elm formatting failed: " .. (result.stderr ~= "" and result.stderr or result.stdout or "elm-format timed out"), vim.log.levels.WARN)
      return
    end
    if result.stdout ~= input then
      local view = vim.fn.winsaveview()
      local lines = vim.split(result.stdout:gsub("\n$", ""), "\n", { plain = true })
      vim.api.nvim_buf_set_lines(event.buf, 0, -1, false, lines)
      vim.fn.winrestview(view)
    end
  end,
})
