local M = {}

-- Load Neorg; assert if not loaded
local neorg_loaded, neorg = pcall(require, "neorg.core")
assert(neorg_loaded, "Neorg is not loaded - please make sure to load Neorg first")

local utils = require("neorg-extras.utils")


local function filter_tasks(input_list)
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

    local state_icons = {
        ["x"] = "󰄬",
        ["_"] = "",
        ["-"] = "󰥔",
        ["="] = "",
        [" "] = "×",
        ["!"] = "⚠",
        ["+"] = "↺",
        ["?"] = "",
    }

    -- Filter out specified states from agenda_states
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

    -- Get current Neorg workspace directory
    local current_workspace = neorg.modules.get_module("core.dirman").get_current_workspace()
    local base_directory = current_workspace[2]

    -- Use ripgrep to find tasks in Neorg files
    local rg_command = [[rg '\* \(\s*(-?)\s*x*\?*!*_*\+*=*\)' --glob '*.norg' --line-number ]]
    .. base_directory
    local rg_results = vim.fn.system(rg_command)

    -- Parse ripgrep results into lines
    local lines = {}
    for line in rg_results:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local task_list = {}

    -- Process lines to extract task information
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
            table.insert(task_list, {
                state = state_icons[task_state],
                filename = file,
                lnum = tonumber(lnum),
                task = text,
            })
        end
        ::continue::
    end

    -- Extract additional agenda data for each task
    for _, task_value in ipairs(task_list) do
        local agenda_data = utils.extract_property_data(task_value.filename, task_value.lnum)
        for key, value in pairs(agenda_data) do
            task_value[key] = value
        end
    end

    return task_list
end

-- Generate agenda from Neorg files
function M.page_view(input_list)
    local task_list = filter_tasks(input_list)

    -- Create and display agenda buffer
    local buffer_lines = {}
    local current_file = nil

    -- Format and insert tasks into the buffer
    for _, entry in ipairs(task_list) do
        if current_file ~= entry.filename then
            if current_file then
                table.insert(buffer_lines, "")
            end
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
        table.insert(buffer_lines, entry.task)
    end
    table.insert(buffer_lines, "")
    table.insert(buffer_lines, "___")

    -- Write formatted lines to the buffer
    local buf, win = utils.create_buffer(buffer_lines)
end

function M.day_view()
    local year = tonumber(os.date("%Y"))
    local month = tonumber(os.date("%m"))
    local day = tonumber(os.date("%d"))

    local timetable = {
        year = year,
        month = month,
        day = day,
        hour = 0,
        min = 0,
        sec = 0,
    }

    -- Get the current weekday and adjust it to treat Monday as the start of the week
    local current_weekday = tonumber(os.date("%w", os.time(timetable)))
    current_weekday = (current_weekday == 0) and 7 or
    current_weekday                                                   -- Adjust Sunday (0) to be the last day of the week (7)

    -- Calculate the start of the week (Monday)
    local start_of_week_timestamp = os.time(timetable) - ((current_weekday - 1) * 24 * 60 * 60)
    local end_of_week_timestamp = start_of_week_timestamp + (6 * 24 * 60 * 60) -- End of the week (Sunday)

    -- Calculate the end of next week (Sunday of the next week)
    local end_of_next_week_timestamp = end_of_week_timestamp + (7 * 24 * 60 * 60)

    local buffer_lines = {}
    table.insert(buffer_lines, "")
    table.insert(buffer_lines, "")
    table.insert(buffer_lines, "___")
    table.insert(buffer_lines, "* Today's Schedule")
    table.insert(buffer_lines, "  /" .. os.date("%A", os.time(timetable)) .. "/ == /" .. year ..
        "-" .. month .. "-" .. day .. "/ == /wk" .. os.date("%U", os.time(timetable)) .. "/")
    table.insert(buffer_lines, "___")
    table.insert(buffer_lines, "")
    table.insert(buffer_lines, "")

    local task_list = filter_tasks({ "undone", "pending", "hold", "important", "ambiguous" })

    local today = {}
    local overdue = {}
    local this_week = {}
    local next_week = {}
    local miscellaneous = {}

    local current_time = os.time()

    for _, task in ipairs(task_list) do
        if task.deadline and tonumber(task.deadline.year) and tonumber(task.deadline.month) and tonumber(task.deadline.day) then
            local task_time = os.time({
                year = tonumber(task.deadline.year),
                month = tonumber(task.deadline.month),
                day = tonumber(task.deadline.day),
                hour = 0,
                min = 0,
                sec = 0,
            })

            if task_time < current_time then
                if tonumber(task.deadline.day) == day and tonumber(task.deadline.month) == month and tonumber(task.deadline.year) == year then
                    table.insert(today, task)
                else
                    table.insert(overdue, task)
                end
            elseif task_time <= end_of_week_timestamp then
                table.insert(this_week, task)
            elseif task_time <= end_of_next_week_timestamp then
                table.insert(next_week, task)
            else
                table.insert(miscellaneous, task)
            end
        else
            table.insert(miscellaneous, task)
        end
    end

    table.insert(buffer_lines, "** Today")
    for _, task in ipairs(today) do
        if task.deadline then
            local deadline_str = "*"
            deadline_str = deadline_str .. "{:" .. task.filename .. ":" .. string.gsub(task.task, "%b()", "") .. "}["
            deadline_str = deadline_str .. task.deadline.hour .. ":" .. task.deadline.minute .. "]*"

            local tags_str = ""
            if task.tag then
                if next(task.tag) ~= nil then
                    for _, tag in ipairs(task.tag) do
                        tags_str = tags_str .. " `" .. tag .. "`"
                    end
                end
            end

            local task_str = "\\[" .. task.state .. "\\] " .. (task.task):match("%)%s*(.+)")

            local priority_str = ""
            if task.priority ~= "" and task.priority ~= nil then
                priority_str = "/" .. task.priority .. "/"
            end

            local line_str = "   " .. deadline_str
            if priority_str ~= "" then
                line_str = line_str .. " :: " .. priority_str
            end
            line_str = line_str .. " :: " .. task_str
            if tags_str ~= "" then
                line_str = line_str .. " :: " .. tags_str
            end
            table.insert(buffer_lines, line_str)
        end
    end
    table.insert(buffer_lines, "")
    table.insert(buffer_lines, "")

    -- Overdue
    table.insert(buffer_lines, "** Overdue")
    for _, task in ipairs(overdue) do
        if task.deadline then
            local task_time = os.time({
                year = tonumber(task.deadline.year),
                month = tonumber(task.deadline.month),
                day = tonumber(task.deadline.day)
            })
            local overdue_years = os.date("%Y", current_time) - os.date("%Y", task_time)
            local overdue_months = os.date("%m", current_time) - os.date("%m", task_time)
            local overdue_days = os.date("%d", current_time) - os.date("%d", task_time)

            if overdue_days < 0 then
                overdue_months = overdue_months - 1
                overdue_days = overdue_days +
                os.date("%d", os.time({
                    year = os.date("%Y", task_time),
                    month = os.date("%m", task_time) + 1,
                    day = 0
                }))
            end

            if overdue_months < 0 then
                overdue_years = overdue_years - 1
                overdue_months = overdue_months + 12
            end

            local overdue_str = "*"
            overdue_str = overdue_str .. "{:" .. task.filename .. ":" .. string.gsub(task.task, "%b()", "") .. "}["
            if overdue_years > 0 then
                overdue_str = overdue_str .. overdue_years .. "y"
            end
            if overdue_months > 0 then
                overdue_str = overdue_str .. overdue_months .. "m"
            end
            if overdue_days > 0 then
                overdue_str = overdue_str .. overdue_days .. "d]*"
            end

            local tags_str = ""
            if task.tag then
                if next(task.tag) ~= nil then
                    for _, tag in ipairs(task.tag) do
                        tags_str = tags_str .. " `" .. tag .. "`"
                    end
                end
            end

            local task_str = "\\[" .. task.state .. "\\] " .. (task.task):match("%)%s*(.+)")

            local priority_str = ""
            if task.priority ~= "" and task.priority ~= nil then
                priority_str = "/" .. task.priority .. "/"
            end

            local line_str = "   " .. overdue_str
            if priority_str ~= "" then
                line_str = line_str .. " :: " .. priority_str
            end
            line_str = line_str .. " :: " .. task_str
            if tags_str ~= "" then
                line_str = line_str .. " :: " .. tags_str
            end
            table.insert(buffer_lines, line_str)
        end
    end

    table.insert(buffer_lines, "")
    table.insert(buffer_lines, "")

    -- This week
    table.insert(buffer_lines, "** This Week")
    for _, task in ipairs(this_week) do
        if task.deadline then
            local task_time = os.time({
                year = tonumber(task.deadline.year),
                month = tonumber(task.deadline.month),
                day = tonumber(task.deadline.day)
            })

            -- Calculate the time remaining until the task's deadline
            local due_years = os.date("%Y", task_time) - os.date("%Y", current_time)
            local due_months = os.date("%m", task_time) - os.date("%m", current_time)
            local due_days = os.date("%d", task_time) - os.date("%d", current_time)

            if due_days < 0 then
                due_months = due_months - 1
                due_days = due_days + os.date("%d", os.time({
                    year = os.date("%Y", task_time),
                    month = os.date("%m", task_time) + 1,
                    day = 0
                }))
            end

            if due_months < 0 then
                due_years = due_years - 1
                due_months = due_months + 12
            end

            local due_str = "*"
            due_str = due_str .. "{:" .. task.filename .. ":" .. string.gsub(task.task, "%b()", "") .. "}["
            if due_years > 0 then
                due_str = due_str .. due_years .. "y"
            end
            if due_months > 0 then
                due_str = due_str .. due_months .. "m"
            end
            if due_days > 0 then
                due_str = due_str .. due_days .. "d]*"
            end

            local tags_str = ""
            if task.tag then
                if next(task.tag) ~= nil then
                    for _, tag in ipairs(task.tag) do
                        tags_str = tags_str .. " `" .. tag .. "`"
                    end
                end
            end

            local task_state_str = "\\[" .. task.state .. "\\] " .. (task.task):match("%)%s*(.+)")

            local priority_str = ""
            if task.priority ~= "" and task.priority ~= nil then
                priority_str = "/" .. task.priority .. "/"
            end

            local line_str = "   " .. due_str
            if priority_str ~= "" then
                line_str = line_str .. " :: " .. priority_str
            end
            line_str = line_str .. " :: " .. task_state_str
            if tags_str ~= "" then
                line_str = line_str .. " :: " .. tags_str
            end
            table.insert(buffer_lines, line_str)
        end
    end
    table.insert(buffer_lines, "")
    table.insert(buffer_lines, "")

    -- Next week
    table.insert(buffer_lines, "** Next Week")
    for _, task in ipairs(next_week) do
        if task.deadline then
            local task_time = os.time({
                year = tonumber(task.deadline.year),
                month = tonumber(task.deadline.month),
                day = tonumber(task.deadline.day)
            })

            -- Calculate the time remaining until the task's deadline
            local due_years = os.date("%Y", task_time) - os.date("%Y", current_time)
            local due_months = os.date("%m", task_time) - os.date("%m", current_time)
            local due_days = os.date("%d", task_time) - os.date("%d", current_time)

            if due_days < 0 then
                due_months = due_months - 1
                due_days = due_days + os.date("%d", os.time({
                    year = os.date("%Y", task_time),
                    month = os.date("%m", task_time) + 1,
                    day = 0
                }))
            end

            if due_months < 0 then
                due_years = due_years - 1
                due_months = due_months + 12
            end

            local due_str = "*"
            due_str = due_str .. "{:" .. task.filename .. ":" .. string.gsub(task.task, "%b()", "") .. "}["
            if due_years > 0 then
                due_str = due_str .. due_years .. "y"
            end
            if due_months > 0 then
                due_str = due_str .. due_months .. "m"
            end
            if due_days > 0 then
                due_str = due_str .. due_days .. "d]*"
            end

            local tags_str = ""
            if task.tag then
                if next(task.tag) ~= nil then
                    for _, tag in ipairs(task.tag) do
                        tags_str = tags_str .. " `" .. tag .. "`"
                    end
                end
            end

            local task_state_str = "\\[" .. task.state .. "\\] " .. (task.task):match("%)%s*(.+)")

            local priority_str = ""
            if task.priority ~= "" and task.priority ~= nil then
                priority_str = "/" .. task.priority .. "/"
            end

            local line_str = "   " .. due_str
            if priority_str ~= "" then
                line_str = line_str .. " :: " .. priority_str
            end
            line_str = line_str .. " :: " .. task_state_str
            if tags_str ~= "" then
                line_str = line_str .. " :: " .. tags_str
            end
            table.insert(buffer_lines, line_str)
        end
    end
    table.insert(buffer_lines, "")
    table.insert(buffer_lines, "")

    table.insert(buffer_lines, "** Miscellaneous")
    for _, task in ipairs(miscellaneous) do
        local unscheduled_str = "*"
        unscheduled_str = unscheduled_str ..
        "{:" .. task.filename .. ":" .. string.gsub(task.task, "%b()", "") .. "}[unscheduled]*"

        local task_str = "\\[" .. task.state .. "\\] " .. (task.task):match("%)%s*(.+)")
        local tags_str = "`untagged`"
        local priority_str = "/unprioritised/"
        local line_str = "   " .. unscheduled_str
        line_str = line_str .. " :: " .. priority_str
        line_str = line_str .. " :: " .. task_str
        line_str = line_str .. " :: " .. tags_str
        table.insert(buffer_lines, line_str)
    end

    local buf, win = utils.create_buffer(buffer_lines)
end

-- Define Neovim command 'NeorgExtras' to process user input
vim.api.nvim_create_user_command(
    'NeorgExtras',
    function(opts)
        local input_list = vim.split(opts.args, ' ')
        if input_list[1] == "Page" then
            local _ = table.remove(input_list, 1)
            M.page_view(input_list)
        elseif input_list[1] == "Day" then
            M.day_view()
        else
            vim.notify("Invalid command!", vim.log.levels.ERROR)
        end
    end,
    { nargs = '+' }
)

return M
