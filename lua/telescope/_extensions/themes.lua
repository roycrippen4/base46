local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local previewers = require('telescope.previewers')

local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_set = require('telescope.actions.set')
local action_state = require('telescope.actions.state')
local config_path = vim.fn.stdpath('config') .. '/lua/plugins/configs/ui.lua'

local function list_themes()
  local default_themes = vim.fn.readdir(vim.fn.stdpath('data') .. '/lazy/base46/lua/base46/themes')
  ---@diagnostic disable-next-line
  local custom_themes = vim.uv.fs_stat(vim.fn.stdpath('config') .. '/lua/themes')

  if custom_themes and custom_themes.type == 'directory' then
    local themes_tb = vim.fn.readdir(vim.fn.stdpath('config') .. '/lua/themes')
    for _, value in ipairs(themes_tb) do
      table.insert(default_themes, value)
    end
  end

  for index, theme in ipairs(default_themes) do
    default_themes[index] = theme:match('(.+)%..+')
  end

  return default_themes
end

---@param old_theme string
---@param selected_theme string
local function replace_theme(old_theme, selected_theme)
  local file = io.open(config_path, 'r')
  if not file then
    vim.notify('Error: Could not open ui.lua', vim.log.levels.ERROR)
    return
  end

  local added_pattern = string.gsub(old_theme, '-', '%%-')
  local new_theme = file:read('*all'):gsub(added_pattern, selected_theme)

  file = io.open(config_path, 'w')
  if not file then
    vim.notify('Error: Could not open ui.lua', vim.log.levels.ERROR)
    return
  end

  file:write(new_theme)
  file:close()

  require('base46').load_all_highlights()
end

-- ---@param new_theme string
-- local function reload_theme(new_theme)
-- print(vim.inspect(dofile(config_path)))
-- require(config_path).ui.theme = new_theme
-- require('base46').load_all_highlights()
-- vim.api.nvim_exec_autocmds('User', { pattern = 'NvChadThemeReload' })
-- end

local function switcher()
  local bufnr = vim.api.nvim_get_current_buf()

  -- show current buffer content in previewer
  local previewer = previewers.new_buffer_previewer({
    define_preview = function(self, _)
      -- add content
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

      -- add syntax highlighting in previewer
      local ft = (vim.filetype.match({ buf = bufnr }) or 'diff'):match('%w+')
      require('telescope.previewers.utils').highlighter(self.state.bufnr, ft)
    end,
  })

  -- our picker function: colors
  local picker = pickers.new({
    prompt_title = '󱥚 Set Theme',
    previewer = previewer,
    finder = finders.new_table({
      results = list_themes(),
    }),
    sorter = conf.generic_sorter(),

    attach_mappings = function(prompt_bufnr, _)
      -- reload theme while typing
      vim.schedule(function()
        vim.api.nvim_create_autocmd('TextChangedI', {
          buffer = prompt_bufnr,
          callback = function()
            if action_state.get_selected_entry() then
              local old_theme = dofile(config_path).ui.theme
              replace_theme(old_theme, action_state.get_selected_entry()[1])
            end
          end,
        })
      end)
      ---@diagnostic disable-next-line
      actions.move_selection_previous:replace(function()
        action_set.shift_selection(prompt_bufnr, -1)
        local old_theme = dofile(config_path).ui.theme
        replace_theme(old_theme, action_state.get_selected_entry()[1])
      end)
      ---@diagnostic disable-next-line
      actions.move_selection_next:replace(function()
        action_set.shift_selection(prompt_bufnr, 1)
        local old_theme = dofile(config_path).ui.theme
        replace_theme(old_theme, action_state.get_selected_entry()[1])
      end)

      ------------ save theme to chadrc on enter ----------------
      actions.select_default:replace(function()
        if action_state.get_selected_entry() then
          local old_theme = dofile(config_path).ui.theme
          local selected_theme = action_state.get_selected_entry()[1]

          replace_theme(old_theme, selected_theme)
          actions.close(prompt_bufnr)
        end
      end)
      return true
    end,
  }, {})

  picker:find()
end

return require('telescope').register_extension({
  exports = { themes = switcher },
})
