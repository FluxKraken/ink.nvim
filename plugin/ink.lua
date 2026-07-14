if vim.g.loaded_ink_nvim == 1 then
  return
end

vim.g.loaded_ink_nvim = 1

require("ink").setup()

