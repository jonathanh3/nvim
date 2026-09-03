-- Match files like `*.js.ejs`, `*.ts.ejs`, `*.json.ejs`, etc.
-- and treat them as if they were the base filetype (`js`, `ts`, `json`, etc.)
-- Neovim 0.12 wraps user patterns as ^pat$; do not add your own $ anchors.
vim.filetype.add({
  filename = {
    [".gitlab-ci.yml"] = "yaml.gitlab",
    [".gitlab-ci.yaml"] = "yaml.gitlab",
  },
  pattern = {
    [".*%.(%a+)%.ejs"] = function(_, _, ext)
      local map = {
        js = "javascript",
        yml = "yaml",
        yaml = "yaml",
        ts = "typescript",
        json = "json",
        css = "css",
        html = "html",
      }
      return map[ext]
    end,
    [".*%.gitlab%-ci%.ya?ml"] = "yaml.gitlab",
    [".*/%.gitlab/.*%.ya?ml"] = "yaml.gitlab",
  },
})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  desc = "Detect Ansible YAML files",
  group = vim.api.nvim_create_augroup("ansible-filetype", { clear = true }),
  pattern = { "*.yml", "*.yaml" },
  callback = function(event)
    local fname = vim.api.nvim_buf_get_name(event.buf)
    local is_ansible = fname:match("ansible/") or fname:match("playbooks/") or
                       fname:match("roles/") or fname:match("group_vars/")
    if is_ansible then
      vim.bo[event.buf].filetype = "yaml.ansible"
    end
  end,
})

vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight on yank",
  group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
  callback = function()
    vim.hl.on_yank({ timeout = 200 })
  end,
})

-- Skip treesitter, folds, and syntax on big files (minified JSON, generated code, …)
local large_file_bytes = 512 * 1024
vim.api.nvim_create_autocmd("BufReadPre", {
  desc = "Mark large files so expensive features can skip them",
  group = vim.api.nvim_create_augroup("large-file", { clear = true }),
  callback = function(event)
    local ok, stat = pcall(vim.uv.fs_stat, event.match)
    if not (ok and stat and stat.size > large_file_bytes) then
      return
    end
    vim.b[event.buf].large_file = true
    vim.opt_local.foldenable = false
    vim.opt_local.swapfile = false
    vim.opt_local.undofile = false
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  desc = "Enable treesitter highlight unless the buffer is a large file",
  group = vim.api.nvim_create_augroup("treesitter-start", { clear = true }),
  callback = function(event)
    if vim.b[event.buf].large_file then
      pcall(vim.treesitter.stop, event.buf)
      vim.bo[event.buf].syntax = "off"
      return
    end
    pcall(vim.treesitter.start)
  end,
})

