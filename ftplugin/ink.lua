vim.bo.commentstring = "// %s"
vim.bo.comments = "s1:/*,mb:*,ex:*/,://"
vim.bo.suffixesadd = ".ink"

vim.b.undo_ftplugin = table.concat({
  "setlocal commentstring<",
  "setlocal comments<",
  "setlocal suffixesadd<",
}, " | ")

