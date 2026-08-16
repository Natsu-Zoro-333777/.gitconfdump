-- theme & transparency

vim.cmd.colorscheme("default")
vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "none" })
vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
vim.api.nvim_set_hl(0, "FloatBorder", { bg = "none" })
vim.api.nvim_set_hl(0, "SignColumn", { bg = "none" })
vim.api.nvim_set_hl(0, "StatusLine", { bg = "#424C80" , fg = "#99DAEE" }) --"#D63B18"
vim.api.nvim_set_hl(0, "StatusLineNC", { bg = "#99DAEE", fg = "#424C80" }) --"#1C1C1C"
vim.api.nvim_set_hl(0, "Tabline", { bg = "none" })
vim.api.nvim_set_hl(0, "TablineFill", { bg = "none", fg = "#DFEFF7" })
vim.api.nvim_set_hl(0, "TablineSel", { bg = "none" })
vim.api.nvim_set_hl(0, "ColorColumn", { bg = "#99DAEE" })
vim.api.nvim_set_hl(0, "CursorColumn", { bg = "#424C80", fg = "#99DAEE" })
vim.api.nvim_set_hl(0, "CursorLine", { bg = "#424C80" , fg = "#99DAEE" }) --"#D63B18"



--========================================
--Statusline
--========================================

--Git branch function with caching and Nerd font icon
local cached_branch = ""
local last_check = 0
local function git_branch()
  local now = vim.loop.now()
  if now - last_check > 5000 then --check every 5 seconds
    cached_branch = vim.fn.system("git branch --show-current 2>/dev/null | tr - d")
    last_check = now
  end
  if cached_branch ~= "" then
    return " \u{e725} " .. cached_branch .. " " --nf-dev-git-branch
  end
  return ""
end

--File type with Nerd Font Icon

local function file_type()
  local ft = vim.bo.filetype
  local icons = {
    lua = "\u{e620} ",
    python = "\u{e73c} ",
    javascript = "\u{e74e} ",
    typescript = "\u{e628} ",
    javascriptreact = "\u{e7ba} ",
    typescriptreact = "\u{e7ba} ",
    html = "\u{e736} ",
    css = "\u{e749} ",
    scss = "\u{e749} ",
    json = "\u{e60b} ",
    markdown = "\u{e73e} ",
    vim = "\u{e62b} ",
    sh = "\u{f489} ",
    bash = "\u{f489} ",
    zsh = "\u{f489} ",
    rust = "\u{e7a8} ",
    go = "\u{e724} ",
    c = "\u{e61e} ",
    cpp = "\u{e61d} ",
    java = "\u{e738} ",
    php = "\u{e73d} ",
    ruby = "\u{e739} ",
    swift = "\u{e755} ",
    kotlin = "\u{e634} ",
    dart = "\u{e798} ",
    elixir = "\u{e62d} ",
    haskell = "\u{e777} ",
    sql = "\u{e706} ",
    yaml = "\u{f481} ",
    toml = "\u{e615} ",
    xml = "\u{f05c} ",
    dockerfile = "\u{f308} ",
    gitcommit = "\u{f418} ",
    gitconfig = "\u{f1d3} ",
    vue = "\u{fd42} ",
    svelte = "\u{e697} ",
    astro = "\u{e628} ",
    asm = "\u{e6ab} ",
  }
  if ft == "" then
    return " \u{f15b} "
  end
  return (icons[ft] or ( " \u{f15b} ") .. ft)
end

--File size with Nerd font icon
local function file_size()
  local size = vim.fn.getfsize(vim.fn.expand('%'))
  if size < 0 then return "" end

  local size_str
  if size < 1024 then
    size_str = size .. "B"
  elseif size < 1024 * 1024 then
    size_str = string.format("%.1fK", size / 1024)
  else
    size_str = string.format("%.1fM", size / 1024 / 1024)
  end
  return " \u{f016} " .. size_str .. " "
end

local function mode_icon()
  local mode = vim.fn.mode()
  local modes = {
    n = " \u{f040} NORMAL",
    i = " \u{f303} INSERT",
    v = " \u{f06e} VISUAL",
    V = " \u{f06e} V-LINE",
    ["\22"] = " \u{f06e} V-BLOCK",
    c = " \u{f120} COMMAND",
    s = " \u{f0c5} SELECT",
    S = " \u{f0c5} S-LINE",
    ["\19"] = " \u{f0c5} S-BLOCK",
    R = " \u{f044} REPLACE",
    r = " \u{f044} REPLACE",
    ["!"] = " \u{f489} SHELL",
    t = " \u{f120} TERMINAL",
  }
  return modes[mode] or (" \u{f059} ") .. mode:upper()
end

_G.mode_icon = mode_icon
_G.git_branch = git_branch
_G.file_type = file_type
_G.file_size = file_size

vim.cmd([[
  highlight  StatusLineBold gui=bold cterm=bold
  ]])
  --Function to change statusline based onwindow focus
  local function setup_dynamic_statusline()
    vim.api.nvim_create_autocmd({"WinEnter", "BufEnter"}, {
      callback = function()
      vim.opt_local.statusline = table.concat {
        " ",
        "%#StatusLineBold#" ,
        "%{v:lua.mode_icon()}" ,
        "%#StatusLine#" ,
        " \u{e0b1} %f %h%m%r" ,
        "%{v:lua.git_branch()}" ,
        "\u{e0b1} " ,
        "%{v:lua.file_type()}" ,
        "\u{e0b1} " ,
        "%{v:lua.file_size()}" ,
        "%=" ,
        " \u{f017} %l:%c %P" ,
      }
    end
  })
  vim.api.nvim_set_hl(0, "StatusLineBold", { bold = true})
  vim.api.nvim_create_autocmd({"WinLeave", "BufLeave"}, {
    callback = function()
      vim.opt_local.statusline = " %f  %h%m%r  \u{e0b1}  %{v:lua.file_type()}  %=  %l:%c  %P "
    end
  })
end

setup_dynamic_statusline()

--====================================================
--Indentation tracking
--====================================================

vim.opt.list = true
vim.opt.listchars = {
  leadmultispace = "| ",
  tab = "» ",
  trail = "·",
  nbsp = "␣",
}
