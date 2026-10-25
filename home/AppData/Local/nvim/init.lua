-- Load the configuration from its managed directory without Windows symlinks.
local config = vim.fn.expand("~/.config/nvim")
vim.opt.runtimepath:prepend(config)
dofile(config .. "/init.lua")
