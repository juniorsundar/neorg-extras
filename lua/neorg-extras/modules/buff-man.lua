local M = {}

function M.create_buffer(buffer_lines)
    -- Create a new buffer for displaying the agenda
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

    -- Function to handle buffer leave event
    local function on_buf_leave()
        local file = vim.api.nvim_buf_get_name(0)
        local row, _ = unpack(vim.api.nvim_win_get_cursor(0))

        vim.cmd("tabclose")

        -- Reopen the file in the previous tab
        vim.cmd("tabprevious")
        vim.cmd("edit " .. file)
        vim.api.nvim_win_set_cursor(0, {row, 0})
    end

    -- Setup an autocommand to observe buffer changes and trigger the function
    vim.api.nvim_create_autocmd("BufLeave", {
        buffer = buf,
        callback = on_buf_leave,
        once = true,
    })

    return buf, win
end

return M
