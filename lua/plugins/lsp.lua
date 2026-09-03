return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  cmd = { "Mason", "MasonInstall", "MasonUninstall", "MasonUninstallAll", "MasonLog", "LspInfo", "LspStart" },
  dependencies = {
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
    "hrsh7th/nvim-cmp",
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-buffer",
    "L3MON4D3/LuaSnip",
    "saadparwaiz1/cmp_luasnip",
    "j-hui/fidget.nvim",
  },

  config = function()
    local mason = require("mason")
    local mason_lspconfig = require("mason-lspconfig")
    local cmp_lsp = require("cmp_nvim_lsp")
    local cmp = require("cmp")
    local luasnip = require("luasnip")

    local capabilities = cmp_lsp.default_capabilities()

    vim.keymap.set("n", "<leader>dc", vim.diagnostic.open_float,
      { desc = "Show diagnostic for current line" })
    vim.keymap.set("n", "dp", function()
      vim.diagnostic.jump({ count = -1, float = true })
    end, { desc = "Go to previous diagnostic" })
    vim.keymap.set("n", "dn", function()
      vim.diagnostic.jump({ count = 1, float = true })
    end, { desc = "Go to next diagnostic" })
    vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist,
      { desc = "Open diagnostic in location list" })
    vim.keymap.set("n", "<leader>dq", vim.diagnostic.setqflist,
      { desc = "Send all diagnostics to quickfix" })
    vim.keymap.set("n", "<leader>dt", function()
      local enabled = vim.diagnostic.config().virtual_text == true
      vim.diagnostic.config({ virtual_text = not enabled })
    end, { desc = "Toggle diagnostic virtual text" })
    vim.keymap.set("n", "<leader>de", function()
      vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.ERROR, float = true })
    end, { desc = "Go to next error" })
    vim.keymap.set("n", "<leader>dE", function()
      vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.ERROR, float = true })
    end, { desc = "Go to previous error" })

    -- Use LspAttach instead of vim.lsp.config("*").on_attach. Server configs from
    -- nvim-lspconfig (ts_ls, pyright, ...) define their own on_attach and would
    -- overwrite a "*" callback, leaving Vim's built-in `gd` (local declaration).
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("UserLspKeymaps", { clear = true }),
      callback = function(event)
        local function buf_set_keymap(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = event.buf, desc = desc })
        end

        buf_set_keymap("n", "K", vim.lsp.buf.hover, "Show hover documentation")
        buf_set_keymap("n", "gd", vim.lsp.buf.definition, "Go to definition")
        buf_set_keymap("n", "gr", vim.lsp.buf.references, "List references")
        buf_set_keymap("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
        buf_set_keymap("n", "<leader>ca", vim.lsp.buf.code_action, "Code actions")
        buf_set_keymap("i", "<C-h>", vim.lsp.buf.signature_help, "Signature help")
      end,
    })

    require("fidget").setup({})
    mason.setup()

    local servers = {
      "pyright",
      "yamlls",
      "ansiblels",
      "gitlab_ci_ls",
      "jsonls",
      "ts_ls",
    }

    -- GitHub Actions verifies the Lua config, not that Mason can fetch servers.
    -- automatic_enable defaults to true and would vim.lsp.enable() every Mason
    -- server (plus our explicit vim.lsp.enable(servers) below).
    mason_lspconfig.setup({
      ensure_installed = vim.env.GITHUB_ACTIONS and {} or servers,
      automatic_enable = false,
    })

    vim.lsp.config("*", {
      capabilities = capabilities,
    })

    local venv = os.getenv("VIRTUAL_ENV")
    local python_path = venv and (venv .. "/bin/python") or (vim.fn.exepath("python") ~= "" and vim.fn.exepath("python") or "python")
    vim.lsp.config("pyright", {
      settings = {
        python = {
          pythonPath = python_path,
        },
      },
    })

    vim.lsp.config("ts_ls", {
      filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "javascript.ejs" },
      settings = {
        javascript = { suggest = { autoImports = true } },
        typescript = { suggest = { autoImports = true } },
      },
    })

    vim.lsp.config("yamlls", {
      filetypes = { "yaml" },
    })

    vim.lsp.config("ansiblels", {
      filetypes = { "yaml.ansible" },
      settings = {
        ansible = {
          validation = {
            lint = {
              enabled = false,
            },
          },
        },
      },
    })

    vim.lsp.config("gitlab_ci_ls", {
      filetypes = { "yaml.gitlab" },
      init_options = {
        cache = vim.fn.stdpath("cache") .. "/gitlab-ci-ls",
        log_path = vim.fn.stdpath("cache") .. "/gitlab-ci-ls/log.txt",
      },
    })

    -- Detach yamlls from specialized YAML files (GitLab CI and Ansible)
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "yaml.gitlab", "yaml.ansible" },
      callback = function(event)
        local yamlls_clients = vim.lsp.get_clients({ bufnr = event.buf, name = "yamlls" })
        for _, client in ipairs(yamlls_clients) do
          -- Detach from this buffer only; stopping the client would kill yamlls
          -- for every other YAML file in the session.
          vim.lsp.buf_detach_client(event.buf, client.id)
        end
      end,
    })

    vim.lsp.enable(servers)

    local cmp_select = { behavior = cmp.SelectBehavior.Select }
    cmp.setup({
      snippet = {
        expand = function(args)
          luasnip.lsp_expand(args.body)
        end,
      },
      mapping = cmp.mapping.preset.insert({
        ["<S-Tab>"] = cmp.mapping.select_prev_item(cmp_select),
        ["<Tab>"] = cmp.mapping.select_next_item(cmp_select),
        ["<Enter>"] = cmp.mapping.confirm({ select = true }),
        ["<C-Space>"] = cmp.mapping.complete(),
      }),
      performance = {
        debounce = 60,
        fetching_timeout = 200,
      },
      sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "luasnip", keyword_length = 2 },
      }, {
        {
          name = "buffer",
          keyword_length = 3,
          option = {
            get_bufnrs = function()
              return { vim.api.nvim_get_current_buf() }
            end,
          },
        },
      }),
      enabled = function()
        if vim.b.large_file then
          return false
        end
        -- Disable completion for JSON files to avoid lag on minified files
        local filetype = vim.api.nvim_get_option_value("filetype", { buf = 0 })
        if filetype == "json" then
          return false
        end
        local context = require("cmp.config.context")
        return not context.in_treesitter_capture("comment") and not context.in_syntax_group("Comment")
      end,
    })

    vim.diagnostic.config({
      float = {
        focusable = false,
        style = "minimal",
        border = "rounded",
        source = "always",
        header = "",
        prefix = "",
      },
    })
  end,
}
