-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
-- Upstream checks only that the directory exists, which an interrupted clone
-- also satisfies: it leaves a lazy.nvim/ holding nothing but .git, and every
-- later start then skips the bootstrap and dies on require("lazy"). Check for
-- the file that is actually required, and clear a useless directory first so
-- git clone has somewhere to write.
local uv = vim.uv or vim.loop
if not uv.fs_stat(lazypath .. "/lua/lazy/init.lua") then
	if uv.fs_stat(lazypath) then
		vim.fn.delete(lazypath, "rf")
	end
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Setup lazy.nvim
require("lazy").setup({
	spec = {
		-- import your plugins
		{ import = "plugins" },
	},
	-- Configure any other settings here. See the documentation for more details.
	-- colorscheme that will be used when installing plugins.
	install = { colorscheme = { "habamax" } },
	-- automatically check for plugin updates
	checker = {
		enabled = true,
		notify = false,
		frequency = 86400, -- check at most once per day
	},
})
