local M = {}

-- Ensure Neorg is loaded
local neorg_loaded, neorg = pcall(require, "neorg.core")
assert(neorg_loaded, "Neorg is not loaded - please make sure to load Neorg first")

M.buf = nil
M.win = nil
M.default_winopts = {
    { "wrap",           nil },
    { "conceallevel",   nil },
    { "foldlevel",      nil },
    { "number",         nil },
    { "relativenumber", nil },
}

--- Navigates to a specific task in a Neorg file and opens it at the correct line.
--- Parses the current Neorg link under the cursor, finds the corresponding task
--- in the target file using `ripgrep`, and opens the file at the task's line.
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
    if parsed_link.link_location_text then
        local search = "rg -n -o --no-filename --fixed-strings " ..
            "') " .. parsed_link.link_location_text .. "' " .. parsed_link.link_file_text .. " | cut -d: -f1"
        local row = tonumber(vim.fn.system(search):match("^%s*(.-)%s*$"))

        vim.cmd("edit +" .. row .. " " .. parsed_link.link_file_text)
    else
        vim.cmd("edit " .. parsed_link.link_file_text)
    end
    vim.api.nvim_buf_delete(M.buf, { force = true })
    -- Populate the default_winopts table with current window options
    for _, opt in ipairs(M.default_winopts) do
        vim.api.nvim_set_option_value(opt[1], opt[2], {win = M.win})
    end
end

--- Standard buffer to display agendas
---@param buffer_lines string[]
---@return integer buffer_number
---@return integer window_number
function M.create_view_buffer(buffer_lines)
    M.buf = vim.api.nvim_create_buf(true, true)

    M.win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(M.win, M.buf)
    vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, buffer_lines)

    -- Populate the default_winopts table with current window options
    for _, opt in ipairs(M.default_winopts) do
        opt[2] = vim.api.nvim_get_option_value(opt[1], {win = M.win})
    end

    -- Set buffer options for display and interaction
    vim.api.nvim_set_option_value("filetype", "norg", { buf = M.buf })
    vim.api.nvim_set_option_value("modifiable", false, { buf = M.buf })
    vim.api.nvim_set_option_value('swapfile', false, { buf = M.buf })
    vim.api.nvim_set_option_value('buftype', 'nofile', { buf = M.buf })
    vim.api.nvim_set_option_value('bufhidden', 'delete', { buf = M.buf })
    vim.api.nvim_set_option_value("readonly", true, { buf = M.buf })
    vim.api.nvim_set_option_value("wrap", false, { win = M.win })
    vim.api.nvim_set_option_value("conceallevel", 2, { win = M.win })
    vim.api.nvim_set_option_value("foldlevel", 999, { win = M.win })
    vim.api.nvim_set_option_value("number", false, { win = M.win })
    vim.api.nvim_set_option_value("relativenumber", false, { win = M.win })

    vim.api.nvim_buf_set_keymap(M.buf, 'n', '<cr>', '', {
        noremap = true,
        silent = true,
        callback = M.open_to_target_task
    })
    vim.api.nvim_buf_set_keymap(M.buf, 'n', 'q', '', {
        noremap = true,
        silent = true,
        callback = function()
            -- Restore the original window options when closing
            for _, opt in ipairs(M.default_winopts) do
                vim.api.nvim_set_option_value(opt[1], opt[2], {win = M.win})
            end
            vim.api.nvim_buf_delete(M.buf, { force = true })
        end
    })

    return M.buf, M.win
end

return M
