local root = assert(vim.env.INK_NVIM_ROOT, "INK_NVIM_ROOT must point to the plugin checkout")

vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:prepend(root .. "/.test-runtime")
package.path = root .. "/tests/?.lua;" .. package.path

vim.cmd("filetype plugin on")
vim.cmd("runtime plugin/ink.lua")
