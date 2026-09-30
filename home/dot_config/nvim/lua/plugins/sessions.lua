vim.pack.add({ { src = "https://github.com/nvim-mini/mini.sessions", version = "stable" } }, { confirm = false })

local sessions = require("mini.sessions")
vim.opt.sessionoptions = { "buffers", "curdir", "folds", "tabpages", "winsize" }
sessions.setup({
  directory = vim.fn.stdpath("state") .. "/sessions",
  file = "", -- Keep session files out of repositories and chezmoi-managed config.
  autoread = false,
  autowrite = false, -- Explicit snapshots: restoring must not overwrite the saved layout.
})

local function project_session()
  local root = vim.fs.normalize(vim.fs.root(vim.fn.getcwd(), ".git") or vim.fn.getcwd())
  local name = vim.fn.fnamemodify(root, ":t"):gsub('[<>:"/\\|?*]', "_")
  return name .. "-" .. vim.fn.sha256(root):sub(1, 8) .. ".vim"
end

vim.keymap.set("n", "<leader>ss", function()
  sessions.write(project_session())
end, { desc = "Save project session" })
vim.keymap.set("n", "<leader>sr", function()
  sessions.read(project_session())
end, { desc = "Restore project session" })
vim.keymap.set("n", "<leader>sl", function()
  sessions.select("read")
end, { desc = "Select saved session" })
vim.keymap.set("n", "<leader>sd", function()
  sessions.select("delete")
end, { desc = "Delete saved session" })
