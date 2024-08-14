local M = {}

-- Ensure Neorg is loaded
local neorg_loaded, neorg = pcall(require, "neorg.core")
assert(neorg_loaded, "Neorg is not loaded - please make sure to load Neorg first")


function M.open_to_target_task()
    -- Wrapping around the esupports.hop module to get the link
    local parsed_link = neorg.modules.get_module("core.esupports.hop").parse_link(
        neorg.modules.get_module("core.esupports.hop").extract_link_node(),
        vim.api.nvim_get_current_buf()
    )
    if not parsed_link then
        return
    end

    -- Since its always going to be a task, we can rg with ') <task>' and filename
    -- to get file row
    local search = "rg -n -o --no-filename --fixed-strings " ..
        "') " .. parsed_link.link_location_text .. "' " .. parsed_link.link_file_text .. " | cut -d: -f1"
    local row = tonumber(vim.fn.system(search):match("^%s*(.-)%s*$"))

    vim.cmd("tabclose")
    vim.cmd("edit +" .. row .. " " .. parsed_link.link_file_text)
end

--- Standard buffer to display agendas
---@param buffer_lines string[]
---@return integer buffer_number
---@return integer window_number
function M.create_buffer(buffer_lines)
    local buf = vim.api.nvim_create_buf(false, true)

    vim.cmd("tabnew")
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, buffer_lines)

    -- Set buffer options for display and interaction
    vim.api.nvim_set_option_value("filetype", "norg", { buf = buf })
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
    vim.api.nvim_set_option_value("readonly", true, { buf = buf })
    vim.api.nvim_set_option_value("wrap", false, { win = win })
    vim.api.nvim_set_option_value("conceallevel", 2, { win = win })
    vim.api.nvim_set_option_value("foldlevel", 999, { win = win })
    vim.api.nvim_set_option_value("number", false, { win = win })
    vim.api.nvim_set_option_value("relativenumber", false, { win = win })

    vim.api.nvim_buf_set_keymap(buf, 'n', '<cr>', '', {
        noremap = true,
        silent = true,
        callback = M.open_to_target_task
    })
    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '', {
        noremap = true,
        silent = true,
        callback = function()
            vim.cmd("tabclose")
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    })

    return buf, win
end

return M
