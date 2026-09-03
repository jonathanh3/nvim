-- Load every plugin and fail on setup errors. Run after init.lua:
--   nvim --headless "+Lazy! restore" "+luafile scripts/verify.lua" "+qa!"
if vim.fn.has("nvim-0.11") ~= 1 then
  io.stderr:write("verify: Neovim >= 0.11 is required (vim.lsp.config)\n")
  os.exit(1)
end

local ok_lazy, lazy_config = pcall(require, "lazy.core.config")
if not ok_lazy then
  io.stderr:write("verify: lazy.nvim did not load: " .. tostring(lazy_config) .. "\n")
  os.exit(1)
end

local Plugin = require("lazy.core.plugin")
local loader = require("lazy.core.loader")

local failures = {}

local function fail(msg)
  failures[#failures + 1] = msg
end

local names = {}
for name, plugin in pairs(lazy_config.plugins) do
  names[#names + 1] = name
  if not plugin._.installed then
    fail(name .. " is not installed")
  end
  if Plugin.has_errors(plugin) then
    fail(name .. " reported install/build errors")
  end
end
table.sort(names)

local notify = vim.notify
vim.notify = function(msg, level, opts)
  if type(msg) ~= "string" then
    msg = vim.inspect(msg)
  end
  if level and level >= vim.log.levels.ERROR then
    fail(msg)
  end
  return notify(msg, level, opts)
end

loader.load(names, { start = "ci" }, { force = true })

local modules = {
  "barbar",
  "cmp",
  "gitsigns",
  "ibl",
  "mason",
  "scm",
  "spectre",
  "telescope",
  "ufo",
  "which-key",
}
for _, mod in ipairs(modules) do
  local ok, err = pcall(require, mod)
  if not ok then
    fail("require('" .. mod .. "') failed: " .. tostring(err))
  end
end

local commands = {
  "Scm",
  "ScmDiff",
  "ScmLog",
  "Telescope",
  "Mason",
  "Lazy",
  "BufferNext",
  "BufferPrevious",
  "BufferClose",
  "BufferCloseAllButCurrent",
}
for _, cmd in ipairs(commands) do
  if vim.fn.exists(":" .. cmd) ~= 2 then
    fail("missing user command :" .. cmd)
  end
end

if vim.g.colors_name ~= "vscode" then
  fail("expected colorscheme vscode, got " .. tostring(vim.g.colors_name))
end

-- Opening a real file fires BufRead hooks (gitsigns, treesitter, ibl, ufo, lsp).
vim.cmd.edit("init.lua")
vim.wait(200)

if #failures > 0 then
  io.stderr:write("verify failed:\n")
  for _, msg in ipairs(failures) do
    io.stderr:write("  - " .. msg .. "\n")
  end
  os.exit(1)
end

print(string.format("verify: %d plugins loaded, %d modules, colorscheme %s", #names, #modules, vim.g.colors_name))
