#!/usr/bin/env -S nvim -l

require("tests.minit")
-- Silence vim.notify
---@diagnostic disable-next-line: duplicate-set-field
vim.notify = function() end
