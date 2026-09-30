-- Keep the Lua configuration shared with WSL without requiring Windows symlinks.
local config = vim.fn.expand("~/.config/nvim")
vim.opt.runtimepath:prepend(config)
dofile(config .. "/init.lua")
