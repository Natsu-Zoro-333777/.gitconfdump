return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "qmljs" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Arch names the Qt 6 server qmlls6. Mason's qmlls package is a
        -- separate nightly and would not match this system's Qt.
        qmlls = {
          mason = false,
          cmd = { "/usr/bin/qmlls6" },
          root_markers = { ".qmlls.ini", "CMakeLists.txt", ".git" },
        },
      },
    },
  },
}
