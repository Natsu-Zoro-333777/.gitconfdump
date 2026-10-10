
--Basic Settings
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true --highlight current line
vim.opt.cursorcolumn = true --highlight current line y axis
vim.opt.wrap = true --wrap text
vim.opt.scrolloff = 10 --keep 10 lines above/below cursor
vim.opt.sidescrolloff = 8 --keep 8 columns left/right of cursor
vim.opt.formatoptions:append("c") --auto-wrap comments
vim.opt.formatoptions:append("t") --auto-wrap text

--Indentation
vim.opt.tabstop = 2 --tab width
vim.opt.shiftwidth = 2 --indent width
vim.opt.softtabstop = 2 --soft tab stop
vim.opt.expandtab = true --use spaces instead of tab
vim.opt.smartindent = true --smart auto-indenting
vim.opt.autoindent = true -- copy indent from current line

--Search Settings
vim.opt.ignorecase = true --case insensitive search
vim.opt.smartcase = true --case sensitive uppercase in search
vim.opt.hlsearch = true --Highlight search results
vim.opt.incsearch = true --show matches as you type

--Visual Settings
vim.opt.termguicolors = true --enable 24-bit colors
vim.opt.signcolumn = "yes" --always show sign column
vim.opt.colorcolumn = "100" --show column at 100 characters
vim.opt.textwidth = 100
vim.opt.showmatch = true --highlight matching brackets
vim.opt.matchtime =  2 --How long to show matching bracket
vim.opt.cmdheight = 0 --cmdline height
vim.opt.completeopt = { "menuone", "noselect", "popup", "fuzzy" } --completion options
vim.opt.complete = ".,w,b,u,o" --current buffer + other buffers + unloaded + omnifunc
vim.opt.autocomplete = true
vim.opt.autocompletedelay = 50 --fast trigger
vim.opt.showmode = true --show mode in commandline
vim.opt.pumheight = 10 --pop up menu height
vim.opt.pumblend = 10 --popup menu transparency
vim.opt.winblend = 0 --floating window transparency
vim.opt.conceallevel = 0 --don't hide markup
vim.opt.concealcursor = "" --don't hide cursor line markup
vim.opt.lazyredraw = true --don't redraw during macros
vim.opt.synmaxcol = 300 --Syntax highlighting limit

--Create undo directory
local undodir = vim.fn.expand("$HOME/nvim/undodir")
if vim.fn.isdirectory(undodir) == 0 then
  vim.fn.mkdir(undodir, "p")
end

--File Handling
vim.opt.backup = false --no backups
vim.opt.writebackup = false --no backups before writing
vim.opt.swapfile = false --no swap files
vim.opt.undofile = true --persistent undo
vim.opt.undodir = vim.fn.expand("$HOME/nvim/undodir") --Undo directory
vim.opt.updatetime = 300 --Faster completion
vim.opt.timeoutlen = 500 --Key timeout duration
vim.opt.ttimeoutlen = 0 --Key code timeout
vim.opt.autoread = true --auto reload files changed outside vim
vim.opt.autowrite = false --no autosave

--Behavior settings
vim.opt.hidden = true --allow hidde buffers
vim.opt.errorbells = false --no error sounds
vim.opt.backspace = "indent,eol,start" --better backspace behavior
vim.opt.autochdir = false --no auto change directory
vim.opt.iskeyword:append("-") --treat dash as part of word
vim.opt.path:append("**") --include subdirectories in search
vim.opt.selection = "exclusive" --Selection behavior
vim.opt.mouse = "a" --enable mouse support
vim.opt.clipboard:append("unnamedplus") --use system clipboard
vim.opt.modifiable = true --allow buffer modifications
vim.opt.encoding = "UTF-8"

--Cursor settings
--vim.opt.guicursor = "n-v-c:block,i-ci-ve:block,r-cr:hor20,o:hor50,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor,sm:block-blinkwait175-blinkoff150-blinkon175"

--Folding settings
vim.opt.foldmethod = "indent"
vim.opt.foldlevel = 99 --Start with all folds open
vim.opt.foldlevelstart = 99
vim.opt.foldenable = true
vim.opt.foldminlines = 1
vim.opt.foldcolumn = "auto"

--Visual indicators
vim.opt.fillchars = {
  fold = " ",
  foldopen = "▼",
  foldclose = "▶",
  foldsep = "|",
  eob = "",
}

--Split behavior
vim.opt.splitbelow = true
vim.opt.splitright = true

--Key mappings
--vim.g.mapleader = " " --Spacaebar is leader
--vim.g.maplocalleader = " " -- set local leader key to space

--Normal mode mappings
--vim.keymap.set("n", "<leader>c", ":nohlsearch<CR>", { desc = "Clear search hightlights" })

--Y to EOL
vim.keymap.set("n", "Y", "y$", { desc = "Yank to end of line" })

--Disable S and various other annoying keymaps
vim.keymap.set("n", "s", '<Nop>', { desc = 'Disable s' })
--vim.keymap.set("n", "<leader>s", '<Nop>', { desc = 'Disable <leader>s' })
vim.keymap.set("n", "S", '<Nop>', { desc = 'Disable S' })
vim.keymap.set("n", ".", '<Nop>', { desc = 'Disable .'})

--Center to screen when jumping
vim.keymap.set("n", "n", "nzzzv", { desc = "Next search result (centered)" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Previous search result (centered)" })
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Half page down (centered)" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Half page up (centered)" })

--Better paste behavior
--vim.keymap.set("x", "<leader>p", '"_dp', { desc = "Paste without yanking" })

--Delete without yanking
--vim.keymap.set({ "n", "v" }, "<leader>d", '"_dd', { desc = "Delete without yanking" })

--Buffer navigation
--vim.keymap.set("n", "<leader>bn", ":bnext<CR>", { desc = "Next buffer" })
--vim.keymap.set("n", "<leader>bp", ":bprevious<CR>", { desc = "Previous buffer" })

--Better window navigation
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "move to left window" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "move to bottom window" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "move to top window" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "move to right window" })

--Splitting & resizing
--vim.keymap.set("n", "<leader>sv", ":vsplit new<CR>", { desc = "Split window vertically" })
--vim.keymap.set("n", "<leader>sh", ":split new<CR>", { desc = "Split window horizontally" })
vim.keymap.set("n", "<C-Up>", ":resize +2<CR>", { desc = "Increase window height" })
vim.keymap.set("n", "<C-Down>", ":resize -2<CR>", { desc = "decrease window height" })
vim.keymap.set("n", "<C-Left>", ":vertical resize -2<CR>", { desc = "Decrease window width" })
vim.keymap.set("n", "<C-Right>", ":vertical resize +2<CR>", { desc = "Increase window width" })

--Move lines up/down
vim.keymap.set("n", "<A-j>", ":m .+1<CR>==", { desc = "Move line down" })
vim.keymap.set("n", "<A-k>", ":m .-2<CR>==", { desc = "Move line up" })
vim.keymap.set("v", "<A-J>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("v", "<A-K>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

--Better indenting in visual mode
vim.keymap.set("v", "<", "<gv", { desc = "Indent left and reselect"})
vim.keymap.set("v", ">", ">gv", { desc = "Indent right and reselect"})

--Quick file navigation
--vim.keymap.set("n", "<leader>ff", ":find ", { desc = "Find File" })

--Better J behavior
vim.keymap.set("n", "J", "mzJ'z", { desc = "Join lines and keep cursor position" })

--Quick config editing
--vim.keymap.set("n", "<leader>rc", ":e $MYVIMRC<CR>", { desc = "Edit config"})
vim.keymap.set("n", "<leader>l", ":so $MYVIMRC<CR>", { desc = "Reload config" })

