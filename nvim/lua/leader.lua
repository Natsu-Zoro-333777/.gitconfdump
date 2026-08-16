vim.g.mapleader = " " --Spacaebar is leader
vim.g.maplocalleader = " " -- set local leader key to space

vim.keymap.set("n", "<leader>c", ":nohlsearch<CR>", { desc = "Clear search hightlights" })

--Paste/Delete without yanking
vim.keymap.set("x", "<leader>p", '"_dp', { desc = "Paste without yanking" })
vim.keymap.set({ "n", "v" }, "<leader>d", '"_dd', { desc = "Delete without yanking" })

--Buffer navigation
vim.keymap.set("n", "<leader>bn", ":bnext<CR>", { desc = "Next buffer" })
vim.keymap.set("n", "<leader>bp", ":bprevious<CR>", { desc = "Previous buffer" })

--Splitting
vim.keymap.set("n", "<leader>sv", ":vsplit new<CR>", { desc = "Split window vertically" })
vim.keymap.set("n", "<leader>sh", ":split new<CR>", { desc = "Split window horizontally" })

--Quick file navigation
vim.keymap.set("n", "<leader>ff", ":find ", { desc = "Find File" })

--Quick config editing
vim.keymap.set("n", "<leader>rc", ":e $MYVIMRC<CR>", { desc = "Edit config"})
vim.keymap.set("n", "<leader>l", ":so $MYVIMRC<CR>", { desc = "Reload config" })

--Copy Full File-path
vim.keymap.set("n", "<leader>pa", function()
  local path = vim.fn.expand("%:p")
    vim.fn.setreg("+", path)
    print("file:", path)
end)




--======================================================
--TABS
--======================================================

--tab display settings
vim.opt.showtabline = 1 --always show tabline (0=never, 1 = when multiple tabs, 2=always)
vim.opt.tabline = '' --use default tabline (empty string use built-in)

--Alt navigation
vim.keymap.set('n', '<leader>tn', ':tabnew<CR>', { desc = 'New tab' })
vim.keymap.set('n', '<leader>tx', ':tabclose<CR>', { desc = 'Close tab' })

--Tab moving
vim.keymap.set('n', '<leader>tm', ':tabmove<CR>', { desc = 'Move tab' })
vim.keymap.set('n', '.', ':tabnext<CR>', { desc = 'Move tab right' })
vim.keymap.set('n', ',', ':tabprevious<CR>', { desc = 'Move tab left' })

--Function to open file in new tab
local function open_file_in_tab()
  vim.ui.input({ prompt = 'File to open in new tab: ', completion = 'file' }, function(input)
    if input and input ~= '' then
      vim.cmd('tabnew ' .. input)
    end
  end)
end

--Function to dupe current tab
local function duplicate_tab()
  local current_file = vim.fn.expand('%:p')
  if current_file ~= '' then
    vim.cmd('tabnew' .. current_file)
  else
    vim.cmd('tabnew')
  end
end

--Function to close tabs to the right
local function close_tabs_right()
  local current_tab = vim.fn.tabpagenr()
  local last_tab = vim.fn.tabpagenr('$')

  for i = last_tab, current_tab + 1, -1 do
    vim.cmd(i .. 'tabclose')
  end
end

--Function to close tabs to the left
local function close_tabs_left()
  local current_tab = vim.fn.tabpagenr()
  for i = current_tab - 1, 1, -1 do
    vim.cmd(i .. '1tabclose')
  end
end

--Enhanced keybindings
vim.keymap.set('n', '<leader>t0', open_file_in_tab, { desc = 'Open file in new tab' })
vim.keymap.set('n', '<leader>td', duplicate_tab, { desc = 'Duplicate current tab' })
vim.keymap.set('n', '<leader>tr', close_tabs_right, { desc = 'Close tabs to the right' })
vim.keymap.set('n', '<leader>tl', close_tabs_left, { desc = 'Close tabs to the left' })

--Function to close buffer but keep tab if it's the only buffer in tab
local function smart_close_buffer()
  local buffers_in_tab = #vim.fn.tabpagebuflist()
  if buffers_in_tab > 1 then
    vim.cmd('bdelete')
  else
    --if it's the only buffer in tab, close the tab
    vim.cmd('tabclose')
  end
end
vim.keymap.set('n', '<leader>bd', smart_close_buffer, { desc = 'Smart close buffer/tab' })

--====================================================
--BUFFER/FILE UTILITIES
--====================================================

vim.keymap.set('n', '<leader>bd', smart_close_buffer, { desc = 'Smart close buffer/tab' })

-- Close all buffers except current
vim.keymap.set('n', '<leader>bo', ':%bd|e#|bd#<CR>', { desc = 'Close all buffers except current' })

--Rename current file
vim.keymap.set('n', '<leader>rr', function()
  local old_name = vim.fn.expand('%')
  local new_name = vim.fn.input('New file name: ', old_name)
  if new_name ~= '' and new_name ~= old_name then
    vim.cmd('saveas ' .. new_name)
  end
end, { desc = 'Rename current file' })

--Copy file path variations
vim.keymap.set('n', '<leader>pf', function()
  local path = vim.fn.expand('%:p')
  vim.fn.setreg('+', path)
  print('Full path: ' .. path)
end, { desc = 'Copy full file path' })

vim.keymap.set('n', '<leader>pr', function()
  local path = vim.fn.expand('%')
  vim.fn.setreg('+', path)
  print('Relative path: ' .. path)
end, { desc = 'Copy full file path' })


