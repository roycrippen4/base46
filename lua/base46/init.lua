local M = {}
local config = dofile(vim.fn.stdpath('config') .. '/lua/plugins/configs/ui.lua')

M.get_theme_tb = function(type)
  local default_path = 'base46.themes.' .. config.ui.theme

  local present1, default_theme = pcall(require, default_path)

  if present1 then
    return default_theme[type]
  else
    error('No such theme!')
  end
end

M.merge_tb = function(...)
  return vim.tbl_deep_extend('force', ...)
end

local change_hex_lightness = require('base46.colors').change_hex_lightness

-- turns color var names in hl_override/hl_add to actual colors
-- hl_add = { abc = { bg = "one_bg" }} -> bg = colors.one_bg
M.turn_str_to_color = function(tb)
  local colors = M.get_theme_tb('base_30')
  local copy = vim.deepcopy(tb)

  for _, hlgroups in pairs(copy) do
    for opt, val in pairs(hlgroups) do
      if opt == 'fg' or opt == 'bg' or opt == 'sp' then
        if not (type(val) == 'string' and val:sub(1, 1) == '#' or val == 'none' or val == 'NONE') then
          hlgroups[opt] = type(val) == 'table' and change_hex_lightness(colors[val[1]], val[2]) or colors[val]
        end
      end
    end
  end

  return copy
end

M.extend_default_hl = function(highlights, integration_name)
  local polish_hl = M.get_theme_tb('polish_hl')

  -- polish themes
  if polish_hl and polish_hl[integration_name] then
    highlights = M.merge_tb(highlights, polish_hl[integration_name])
  end

  -- transparency
  if config.ui.transparency then
    local glassy = require('base46.glassy')

    for key, value in pairs(glassy) do
      if highlights[key] then
        highlights[key] = M.merge_tb(highlights[key], value)
      end
    end
  end

  if config.ui.hl_override then
    local overriden_hl = M.turn_str_to_color(config.ui.hl_override)

    for key, value in pairs(overriden_hl) do
      if highlights[key] then
        highlights[key] = M.merge_tb(highlights[key], value)
      end
    end
  end

  return highlights
end

M.load_integrationTB = function(name)
  local highlights = require('base46.integrations.' .. name)
  return M.extend_default_hl(highlights, name)
end

-- convert table into string
M.table_to_str = function(tb)
  local result = ''

  for hlgroupName, hlgroup_vals in pairs(tb) do
    local hlname = "'" .. hlgroupName .. "',"
    local opts = ''

    for optName, optVal in pairs(hlgroup_vals) do
      local valueInStr = ((type(optVal)) == 'boolean' or type(optVal) == 'number') and tostring(optVal) or '"' .. optVal .. '"'
      opts = opts .. optName .. '=' .. valueInStr .. ','
    end

    result = result .. 'vim.api.nvim_set_hl(0,' .. hlname .. '{' .. opts .. '})'
  end

  return result
end

M.saveStr_to_cache = function(filename, tb)
  -- Thanks to https://github.com/nullchilly and https://github.com/EdenEast/nightfox.nvim
  -- It helped me understand string.dump stuff

  local bg_opt = "vim.o.termguicolors=true vim.o.bg='" .. M.get_theme_tb('type') .. "'"
  local defaults_cond = filename == 'defaults' and bg_opt or ''

  local lines = 'return string.dump(function()' .. defaults_cond .. M.table_to_str(tb) .. 'end, true)'
  local file = io.open(vim.g.base46_cache .. filename, 'wb')

  if file then
    file:write(loadstring(lines)())
    file:close()
  end
end

M.compile = function()
  ---@diagnostic disable-next-line
  if not vim.uv.fs_stat(vim.g.base46_cache) then
    vim.fn.mkdir(vim.g.base46_cache, 'p')
  end

  for _, filename in ipairs(config.ui.base46.integrations) do
    M.saveStr_to_cache(filename, M.load_integrationTB(filename))
  end
end

M.load_all_highlights = function()
  require('plenary.reload').reload_module('base46')
  M.compile()

  for _, filename in ipairs(config.ui.base46.integrations) do
    dofile(vim.g.base46_cache .. filename)
  end

  -- update blankline
  pcall(function()
    ---@diagnostic disable-next-line
    require('ibl').update()
  end)
end

M.override_theme = function(default_theme, theme_name)
  local changed_themes = config.ui.changed_themes
  return M.merge_tb(default_theme, changed_themes.all or {}, changed_themes[theme_name] or {})
end

return M
