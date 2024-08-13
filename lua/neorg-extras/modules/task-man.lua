local M = {}

-- Ensure Neorg is loaded
local neorg_loaded, neorg = pcall(require, "neorg.core")
assert(neorg_loaded, "Neorg is not loaded - please make sure to load Neorg first")

local meta_man = require("neorg-extras.modules.meta-man")

-- Define state mappings
local state_to_symbol_mapping = {
    done = "x",
    cancelled = "_",
    pending = "-",
    hold = "=",
    undone = " ",
    important = "!",
    recurring = "+",
    ambiguous = "?"
}

local symbol_to_icon_mapping = {
    ["x"] = "󰄬",
    ["_"] = "",
    ["-"] = "󰥔",
    ["="] = "",
    [" "] = "×",
    ["!"] = "⚠",
    ["+"] = "↺",
    ["?"] = "",
}

function M.blacklist_states(input_list)
    local filtered_state_icons = {}
    for state, symbol in pairs(state_to_symbol_mapping) do
        if not vim.tbl_contains(input_list, state) then
            filtered_state_icons[symbol] = symbol_to_icon_mapping[symbol]
        end
    end
    return filtered_state_icons
end

function M.find_tasks_in_workspace(base_directory)
    local rg_command = [[rg '\* \(\s*(-?)\s*x*\?*!*_*\+*=*\)' --glob '*.norg' --line-number ]] .. base_directory
    return vim.fn.systemlist(rg_command)
end

function M.parse_task_line(line)
    local file, lnum, text = line:match("([^:]+):(%d+):(.*)")
    local task_state = text:match("%((.)%)")
    return file, tonumber(lnum), text, task_state
end

function M.add_agenda_data(task)
    local agenda_data = meta_man.extract_property_metadata(task.filename, task.lnum)
    if agenda_data then
        for key, value in pairs(agenda_data) do
            task[key] = value
        end
    end
    return task
end

function M.filter_tasks(input_list)
    local blacklisted_state_icons = M.blacklist_states(input_list)
    local base_directory = neorg.modules.get_module("core.dirman").get_current_workspace()[2]
    local lines = M.find_tasks_in_workspace(base_directory)

    -- Filter and map tasks
    local task_list = {}
    for _, line in ipairs(lines) do
        local file, lnum, text, task_state_symbol = M.parse_task_line(line)
        if not blacklisted_state_icons[task_state_symbol] and file and lnum and text then
            local task = {
                state = symbol_to_icon_mapping[task_state_symbol],
                filename = file,
                lnum = lnum,
                task = text,
            }
            table.insert(task_list, M.add_agenda_data(task))
        end
    end

    return task_list
end

return M
