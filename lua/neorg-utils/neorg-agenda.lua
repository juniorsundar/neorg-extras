local M = {}

-- Ensure Neorg is loaded; otherwise, throw an error
local neorg_loaded, neorg = pcall(require, "neorg.core")
assert(neorg_loaded, "Neorg is not loaded - please make sure to load Neorg first")

local utils = require("neorg-utils.utils")

-- Creates a new buffer to display the agenda items extracted from the quickfix list.
-- The buffer is opened in a new tab and is populated with tasks from various files.
-- Each file's tasks are grouped together, with the filename and any extracted metadata
-- (e.g., title) displayed as a header.
local function create_agenda_buffer(quickfix_list)
    -- Create a new buffer for displaying the agenda
    local buf = vim.api.nvim_create_buf(false, true)

    -- Initialize the lines that will be written to the buffer
    local buffer_lines = {}
    local current_file = nil

    -- Loop through the quickfix list to format and insert tasks into the buffer
    for _, entry in ipairs(quickfix_list) do
        -- Add a file header if the file has changed
        if current_file ~= entry.filename then
            if current_file then
                table.insert(buffer_lines, "") -- Separate different files with a blank line
            end
            -- Extract and insert file metadata (if available) or just the filename
            local file_metadata = utils.extract_file_metadata(entry.filename)
            table.insert(buffer_lines, "___")
            table.insert(buffer_lines, "")
            if file_metadata then
                table.insert(buffer_lines, "{:" .. entry.filename .. ":}[" .. file_metadata.title .. "]")
            else
                table.insert(buffer_lines, "{:" .. entry.filename .. ":}")
            end
            current_file = entry.filename
        end
        -- Insert the task description
        table.insert(buffer_lines, entry.task)
    end
    -- End the buffer with a separator line
    table.insert(buffer_lines, "")
    table.insert(buffer_lines, "___")

    -- Write the formatted lines to the buffer
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, buffer_lines)

    -- Open the buffer in a new tab and configure the buffer options
    vim.cmd("tabnew")
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)

    -- Set buffer options for display and interaction
    vim.api.nvim_set_option_value("filetype", "norg", { buf = buf })
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
    vim.api.nvim_set_option_value("readonly", true, { buf = buf })
    vim.api.nvim_set_option_value("wrap", false, { win = win })
    vim.api.nvim_set_option_value("conceallevel", 2, { win = win })
    vim.api.nvim_set_option_value("foldlevel", 999, { win = win })

    -- Map 'q' to close the tab
    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':tabclose<CR>', { noremap = true, silent = true })

    -- Optional: Set filetype to norg for syntax highlighting (if available)
end

-- Reads a specific line from a given file.
-- The function iterates through the file's lines until the specified line number is reached.
local function read_line(file, line_number)
    local current_line = 0
    for line in file:lines() do
        current_line = current_line + 1
        if current_line == line_number then
            return line
        end
    end
    return nil
end

-- Extracts agenda-related data from a file, starting from a specific line.
-- If the line following the specified one contains '@data agenda', the function
-- collects lines until it encounters '@end'. It returns the extracted lines or nil if not found.
local function extract_agenda_data(filename, line_number)
    local file = io.open(filename, "r")
    if not file then
        vim.notify("Error opening file: " .. filename, vim.log.levels.ERROR)
        return nil
    end

    local next_line = read_line(file, line_number + 1)
    if next_line and string.match(next_line, "@data agenda") then
        local agenda_lines = {}
        for line in file:lines() do
            if string.match(line, "@end") then
                break
            end
            table.insert(agenda_lines, line)
        end
        file:close()
        return agenda_lines
    else
        file:close()
        return nil
    end
end

-- Main function to generate an agenda from Neorg files.
-- It searches for tasks within Neorg files based on specified states, filters them,
-- and displays the resulting tasks in a new buffer.
function M.neorg_agenda(input_list)
    local agenda_states = {
        { "done",      "x" },
        { "cancelled", "_" },
        { "pending",   "-" },
        { "hold",      "=" },
        { "undone",    " " },
        { "important", "!" },
        { "recurring", "+" },
        { "ambiguous", "?" }
    }

    -- Filter out the agenda states provided in the input_list
    local filtered_states = {}
    for _, state in ipairs(agenda_states) do
        local found = false
        for _, input in ipairs(input_list) do
            if state[1] == input then
                found = true
                break
            end
        end
        if not found then
            table.insert(filtered_states, state)
        end
    end

    -- Get the current Neorg workspace and its base directory
    local current_workspace = neorg.modules.get_module("core.dirman").get_current_workspace()
    local base_directory = current_workspace[2]

    -- Use ripgrep to find tasks in Neorg files
    local rg_command = [[rg '\* \(\s*(-?)\s*x*\?*!*_*\+*=*\)' --glob '*.norg' --line-number ]] .. base_directory
    local rg_results = vim.fn.system(rg_command)

    -- Parse the ripgrep results into individual lines
    local lines = {}
    for line in rg_results:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local quickfix_list = {}

    -- Process each line to extract relevant task information
    for _, line in ipairs(lines) do
        local file, lnum, text = line:match("([^:]+):(%d+):(.*)")
        local task_state = text:match("%((.)%)")
        local found = false
        for _, state in ipairs(filtered_states) do
            if state[2] == task_state then
                found = true
                break
            end
        end
        if found then
            goto continue
        end
        if file and lnum and text then
            table.insert(quickfix_list, {
                filename = file,
                lnum = tonumber(lnum),
                task = text,
            })
        end
        ::continue::
    end

    -- For each task, attempt to extract additional agenda data
    for _, qf_value in ipairs(quickfix_list) do
        local agenda_data = extract_agenda_data(qf_value.filename, qf_value.lnum)
        if agenda_data then
            for _, entry in ipairs(agenda_data) do
                for line in string.gmatch(entry, "[^\r\n]+") do
                    local key, value = line:match("^%s*([^:]+):%s*(.*)")
                    if key == "started" or key == "completed" or key == "deadline" then
                        local date, time = value:match("([^|]+)|([^|]+)")
                        qf_value[key] = { date = date, time = time }
                    else
                        qf_value[key] = value
                    end
                end
            end
        end
    end

    -- Create and display the agenda buffer with the collected tasks
    create_agenda_buffer(quickfix_list)
end

-- Define a Neovim command 'NeorgUtils' that processes user input.
-- If the first argument is "Agenda", it triggers the agenda generation function.
vim.api.nvim_create_user_command(
    'NeorgUtils',
    function(opts)
        -- Split the input into a list of strings
        local input_list = vim.split(opts.args, ' ')
        if input_list[1] == "Agenda" then
            local _ = table.remove(input_list, 1)
            M.neorg_agenda(input_list)
        else
            vim.notify("Invalid command!", vim.log.levels.ERROR)
        end
    end,
    { nargs = '+' } -- Allow one or more arguments
)

return M
