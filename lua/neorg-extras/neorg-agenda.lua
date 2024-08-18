local M = {}

local meta_man = require("neorg-extras.modules.meta-man")
local buff_man = require("neorg-extras.modules.buff-man")
local task_man = require("neorg-extras.modules.task-man")

-- Sort function specifically for today's tasks by hour and minute
local function sort_today_tasks(a, b)
    local a_time = os.time({
        year = tonumber(a.deadline.year) or 2024,
        month = tonumber(a.deadline.month) or 8,
        day = tonumber(a.deadline.day) or 12,
        hour = tonumber(a.deadline.hour) or 0,
        min = tonumber(a.deadline.minute) or 0,
        sec = 0,
    })

    local b_time = os.time({
        year = tonumber(b.deadline.year) or 2024,
        month = tonumber(b.deadline.month) or 8,
        day = tonumber(b.deadline.day) or 12,
        hour = tonumber(b.deadline.hour) or 0,
        min = tonumber(b.deadline.minute) or 0,
        sec = 0,
    })

    return a_time < b_time
end

-- Sort function to prioritize by time to deadline and priority
local function sort_by_time_and_priority(a, b)
    local current_time = os.time()
    local time_a = os.time({
        year = tonumber(a.deadline.year) or 2024,
        month = tonumber(a.deadline.month) or 8,
        day = tonumber(a.deadline.day) or 12,
        hour = tonumber(a.deadline.hour) or 0,
        min = tonumber(a.deadline.minute) or 0,
        sec = 0,
    }) - current_time

    local time_b = os.time({
        year = tonumber(b.deadline.year) or 2024,
        month = tonumber(b.deadline.month) or 8,
        day = tonumber(b.deadline.day) or 12,
        hour = tonumber(b.deadline.hour) or 0,
        min = tonumber(b.deadline.minute) or 0,
        sec = 0,
    }) - current_time

    if time_a ~= time_b then
        return time_a < time_b
    end

    local priority_a = a.priority or "Z"
    local priority_b = b.priority or "Z"
    return priority_a < priority_b
end

--- Due to repetition of overdue, this_week and next_week lines,
--- we create a function that can repeatedly generate the buffer lines.
--- @param task table
--- @param curr_time integer
--- @return table
local function format_task_line(task, curr_time)
    local task_time = os.time({
        year = tonumber(task.deadline.year) or 2024,
        month = tonumber(task.deadline.month) or 8,
        day = tonumber(task.deadline.day) or 12,
    })

    local is_today = (task.deadline.year - tonumber(os.date("%Y")) == 0) and
        (task.deadline.month - tonumber(os.date("%m")) == 0) and
        (task.deadline.day - tonumber(os.date("%d")) == 0)

    local years_diff = nil
    local months_diff = nil
    local days_diff = nil
    local time_str = ""
    if is_today then
        years_diff = os.date("%Y", curr_time) - os.date("%Y", task_time)
        months_diff = os.date("%m", curr_time) - os.date("%m", task_time)
        days_diff = os.date("%d", curr_time) - os.date("%d", task_time)

        time_str = "*"
        time_str = time_str .. "{:" .. task.filename .. ":" .. string.gsub(task.task, "%b()", "") .. "}["
        time_str = time_str .. task.deadline.hour .. ":" .. task.deadline.minute .. "]*"
    else
        if task_time > curr_time then
            years_diff = os.date("%Y", task_time) - os.date("%Y", curr_time)
            months_diff = os.date("%m", task_time) - os.date("%m", curr_time)
            days_diff = os.date("%d", task_time) - os.date("%d", curr_time)
        else
            years_diff = os.date("%Y", curr_time) - os.date("%Y", task_time)
            months_diff = os.date("%m", curr_time) - os.date("%m", task_time)
            days_diff = os.date("%d", curr_time) - os.date("%d", task_time)
        end

        if days_diff < 0 then
            months_diff = months_diff - 1
            days_diff = days_diff + os.date("%d", os.time({
                year = os.date("%Y", task_time),
                month = os.date("%m", task_time) + 1,
                day = 0
            }))
        end

        if months_diff < 0 then
            years_diff = years_diff - 1
            months_diff = months_diff + 12
        end

        time_str = "*{:" .. task.filename .. ":" .. string.gsub(task.task, "^(%*+)%s*%b()%s*", "%1 ") .. "}["

        if years_diff > 0 then
            time_str = time_str .. years_diff .. "y"
        end
        if months_diff > 0 then
            time_str = time_str .. months_diff .. "m"
        end
        if days_diff > 0 then
            time_str = time_str .. days_diff .. "d]*"
        end
    end

    local task_state_str = "\\[" .. task.state .. "\\] " .. (task.task):match("%)%s*(.+)")

    local priority_str = "  "
    if task.priority ~= "" and task.priority ~= nil then
        priority_str = priority_str .. "*" .. task.priority .. "*"
    else
        priority_str = priority_str .. " "
    end
    priority_str = priority_str .. "  "

    local line_str = "   " .. time_str
    line_str = line_str .. " ::" .. priority_str
    line_str = line_str .. ":: " .. task_state_str

    return line_str
end

--- Adds the header and trailing line breaks to encapsulate the task lines
---
--- @param buf_lines table
--- @param header string
--- @param tasks table
--- @param curr_time integer
local function insert_task_lines(buf_lines, header, tasks, curr_time)
    table.insert(buf_lines, "** " .. header)
    for _, task in ipairs(tasks) do
        if task.deadline then
            table.insert(buf_lines, format_task_line(task, curr_time))
        end
    end
    table.insert(buf_lines, "")
    table.insert(buf_lines, "")
end


--- Generate agenda from Neorg files
---@param input_list table
function M.page_view(input_list)
    local task_list = task_man.filter_tasks(input_list)

    -- Create and display agenda buffer
    local buffer_lines = {}
    local current_file = nil

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
        current_weekday -- Adjust Sunday (0) to be the last day of the week (7)

    table.insert(buffer_lines, "")
    table.insert(buffer_lines, "")
    table.insert(buffer_lines, "___")
    table.insert(buffer_lines, "* Today's Schedule")
    table.insert(buffer_lines, "  " .. os.date("%A", os.time(timetable)) .. " == " .. year ..
        "-" .. month .. "-" .. day .. " == wk" .. os.date("%U", os.time(timetable)))
    table.insert(buffer_lines, "___")
    table.insert(buffer_lines, "")
    table.insert(buffer_lines, "")
    -- Format and insert tasks into the buffer
    for _, entry in ipairs(task_list) do
        if current_file ~= entry.filename then
            if current_file then
                table.insert(buffer_lines, "")
            end
            local file_metadata = meta_man.extract_file_metadata(entry.filename)
            -- table.insert(buffer_lines, "___")
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
    -- table.insert(buffer_lines, "___")

    -- Write formatted lines to the buffer
    local _, _ = buff_man.create_view_buffer(buffer_lines)
end

--- Generate the Agenda Day View
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
        current_weekday -- Adjust Sunday (0) to be the last day of the week (7)

    -- Calculate the start of the week (Monday)
    local start_of_week_timestamp = os.time(timetable) - ((current_weekday - 1) * 24 * 60 * 60)
    local end_of_week_timestamp = start_of_week_timestamp + (6 * 24 * 60 * 60) -- End of the week (Sunday)

    -- Calculate the end of next week (Sunday of the next week)
    local end_of_next_week_timestamp = end_of_week_timestamp + (7 * 24 * 60 * 60)

    local current_time = os.time()

    local buffer_lines = {}
    table.insert(buffer_lines, "")
    table.insert(buffer_lines, "")
    table.insert(buffer_lines, "___")
    table.insert(buffer_lines, "* Today's Schedule")
    table.insert(buffer_lines, "  " .. os.date("%A", os.time(timetable)) .. " == " .. year ..
        "-" .. month .. "-" .. day .. " == wk" .. os.date("%U", os.time(timetable)))
    table.insert(buffer_lines, "___")
    table.insert(buffer_lines, "")
    table.insert(buffer_lines, "")

    local task_list = task_man.filter_tasks({
        "undone",
        "pending",
        "hold",
        "important",
        "ambiguous"
    })

    local today = {}
    local overdue = {}
    local this_week = {}
    local next_week = {}
    local miscellaneous = {}

    -- Categorize and sort tasks
    for _, task in ipairs(task_list) do
        if task.deadline and tonumber(task.deadline.year) and tonumber(task.deadline.month) and tonumber(task.deadline.day) then
            local task_time = os.time({
                year = tonumber(task.deadline.year) or 2024,
                month = tonumber(task.deadline.month) or 8,
                day = tonumber(task.deadline.day) or 12,
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

    -- Sort each category
    table.sort(today, sort_today_tasks)
    table.sort(overdue, sort_by_time_and_priority)
    table.sort(this_week, sort_by_time_and_priority)
    table.sort(next_week, sort_by_time_and_priority)

    insert_task_lines(buffer_lines, "Today", today, current_time)
    insert_task_lines(buffer_lines, "Overdue", overdue, current_time)
    insert_task_lines(buffer_lines, "This Week", this_week, current_time)
    insert_task_lines(buffer_lines, "Next Week", next_week, current_time)

    table.insert(buffer_lines, "** Miscellaneous")
    for _, task in ipairs(miscellaneous) do
        local unscheduled_str = "*"
        unscheduled_str = unscheduled_str ..
            "{:" .. task.filename .. ":" .. string.gsub(task.task, "%b()", "") .. "}[unscheduled]*"

        local task_str = "\\[" .. task.state .. "\\] " .. (task.task):match("%)%s*(.+)")
        local tags_str = "`untagged`"
        local priority_str = "*unprioritised*"
        local line_str = "   " .. unscheduled_str
        line_str = line_str .. " :: " .. priority_str
        line_str = line_str .. " :: " .. task_str
        line_str = line_str .. " :: " .. tags_str
        table.insert(buffer_lines, line_str)
    end

    local _, _ = buff_man.create_view_buffer(buffer_lines)
end

--- Generate Tag View
function M.tag_view()
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
        current_weekday -- Adjust Sunday (0) to be the last day of the week (7)

    local current_time = os.time()

    local buffer_lines = {}
    table.insert(buffer_lines, "")
    table.insert(buffer_lines, "")
    table.insert(buffer_lines, "___")
    table.insert(buffer_lines, "* Today's Schedule")
    table.insert(buffer_lines, "  " .. os.date("%A", os.time(timetable)) .. " == " .. year ..
        "-" .. month .. "-" .. day .. " == wk" .. os.date("%U", os.time(timetable)))
    table.insert(buffer_lines, "___")
    table.insert(buffer_lines, "")
    table.insert(buffer_lines, "")

    local task_list = task_man.filter_tasks({
        "undone",
        "pending",
        "hold",
        "important",
        "ambiguous"
    })
    local tag_task_table = {}
    tag_task_table["untagged"] = {}
    for _, task in ipairs(task_list) do
        if task.tag then
            for _, tag in ipairs(task.tag) do
                if not tag_task_table[tag] then
                    tag_task_table[tag] = {}
                end
                table.insert(tag_task_table[tag], task)
            end
        else
            table.insert(tag_task_table["untagged"], task)
        end
    end

    for key, tasks in pairs(tag_task_table) do
        insert_task_lines(buffer_lines, "`" .. key .. "`", tasks, current_time)
    end

    local _, _ = buff_man.create_view_buffer(buffer_lines)
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
        elseif input_list[1] == "Tag" then
            M.tag_view()
        elseif input_list[1] == "Metadata" then
            local _ = table.remove(input_list, 1)
            if input_list[1] == "update" then
                meta_man.update_property_metadata()
            elseif input_list[1] == "delete" then
                vim.notify("Not implemented yet", vim.log.levels.ERROR)
            end
        else
            vim.notify("Invalid command!", vim.log.levels.ERROR)
        end
    end,
    { nargs = '+' }
)

return M
