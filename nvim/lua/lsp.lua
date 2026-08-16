
--========================================
-- LSP CONFIGURATION
--========================================

--LSP Settings
  --Show diagnostic signs in the gutter
  local signs = {
    Error = "\u{f06a} ", --exclamation circle
    Warn = "\u{f071} ", --exclamation triangle
    Hint = "\u{f0eb} ", --lightbulb
    Info = "\u{f05a} ", --info circle
  }
  for type, icon in pairs(signs) do
    vim.fn.sign_define("DiagnosticSign" .. type, {
      text = icon,
      texthl = "DiagnosticSign" .. type,
    })
  end
  --Diagnostic Configuartion
  vim.diagnostic.config({
    virtual_text = {
      prefix = '●',
      spacing = 4,
    },
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    float = {  border = "rounded",
    source = "if_many",
    header = " ",
    prefix = " ",
    },
  })

 --LSP Attach
 vim.api.nvim_create_autocmd("LspAttach", {
   group = vim.api.nvim_create_augroup("UserConfig", { clear = false }),
   callback = function(ev)
     local client = vim.lsp.get_client_by_id(ev.data.client_id)
     local bufnr = ev.buf
     if client and client:supports_method("textDocument/completion") then
       vim.lsp.completion.enable(true, ev.data.client_id, bufnr, {
         autotrigger = true,
       })
     end


  --LSP keymaps (set when LSP attaches)
      local opts = { buffer = bufnr, silent = true }
      vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
      vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
      vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
      vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
      vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
      vim.keymap.set('n', '<leader>D', vim.lsp.buf.type_definition, opts)
      vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
      vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
      vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
      vim.keymap.set('n', '<leader>f', function()
        vim.lsp.buf.format({ async = true })
      end, opts)
    end,
  })

--LSP diagnostic keymaps (always available)
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic list' })
vim.keymap.set('n', '<leader>dl', vim.diagnostic.open_float, { desc = 'Show line disanostics' })


--====================================================
--Enable LSP Servers
--====================================================

--Define lua configuration
vim.lsp.config("lua_ls", {
    cmd = { "lua-language-server" },
    filetypes = { "lua" },
    root_markers = { ".luarc.json", ".nvim.lua", "init.lua", ".git" },
    settings = {
        Lua = {
            runtime = { version = "LuaJIT" },
            diagnostics = { globals = { "vim" } },
            workspace = {
                checkThirdParty = false,
                library = { vim.fn.expand("$VIMRUNTIME/lua") },
            },
            telemetry = { enable = false },
        },
    },
})

--Python
vim.lsp.config("basedpyright", {
  cmd = { vim.fn.expand("$HOME/Projects/VENV/bin/basedpyright-langserver"), "--stdio" },
  filetypes = { "python" },
  root_markers = { "pyproject.toml", "setup.py", "requirements.txt", ".git" },
  settings = {
    python = {
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "workspace",
        typeCheckingMode = "basic",
      },
    },
  },
})

--C/C++
vim.lsp.config("clangd", {
  cmd = { "clangd", "--background-index", "--clang-tidy", "--header-insertion=iwyu",
  "--completion-style=detailed" },
  filetypes = { "c", "cpp", "objc", "objcpp" },
  root_markers = { "compile_commands.json", "CMakeLists.txt", ".git" },
  single_file_support = true,
})

--ASM(NASM)
vim.lsp.config("asm_lsp", {
  cmd = { vim.fn.expand("$HOME/.cargo/bin/asm-lsp") },
  filetypes = { "asm", "s", "S" },
  root_markers = { ".asm-lsp.toml", ".git" },
  single_file_support = true,
})




--Enable the servers
vim.lsp.enable( { "lua_ls", "basedpyright", "clangd", "asm_lsp" } )


