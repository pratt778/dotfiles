vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local isVsCode = vim.g.vscode
if isVsCode then
	require 'vs_config'
else
	require 'prat.configs'
	require 'prat.plugin'
end
