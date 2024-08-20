local neorg = require('neorg.core')
local module = neorg.modules.create('external.many-mans') -- Wish death upon me
-- Blood in my eye, dog, and I can't see
-- I'm tryin' to be what I'm destined to be
-- And neorg's tryin' to take my life away
-- https://www.youtube.com/watch?v=5D3crqpClPY

module.setup = function()
    return {
        success = true,
        requires = {
            "core.integrations.treesitter",
            "core.dirman",
            "core.esupports.hop"
        }
    }
end

module.public = {
    -- Helps know what to look for
    ["meta-man"] = {
        setup_treesitter_folding = function()
            -- Ensure the 'norg' parser is installed and loaded
            local neorg_folds_file = vim.fn.stdpath("data") .. "/lazy/neorg/queries/norg/folds.scm"
            local _ = require("nvim-treesitter.parsers").get_parser_configs().norg

            local property_query = [[
            (ranged_verbatim_tag
              name: (tag_name) @name (#eq? @name "data")) @fold
            ]]

            local neorg_query = ""
            if vim.fn.filereadable(neorg_folds_file) == 1 then
                neorg_query = table.concat(vim.fn.readfile(neorg_folds_file), "\n")
            else
                vim.api.nvim_err_writeln("Failed to find Neorg Tree-sitter query file: " .. neorg_folds_file)
            end
            local combined_query = neorg_query .. "\n" .. property_query
            vim.treesitter.query.set("norg", "folds", combined_query)
        end,

        is_present_property_metadata = function(bufnr)
            bufnr = bufnr or vim.api.nvim_get_current_buf()
            local parser = vim.treesitter.get_parser(bufnr, 'norg')
            local tree = parser:parse()[1]

            -- Get the current cursor position
            local cursor_row, _ = unpack(vim.api.nvim_win_get_cursor(0))
            cursor_row = cursor_row - 1

            -- Define the query for all heading levels
            local heading_query_string = [[
            (heading6) @heading6
            (heading5) @heading5
            (heading4) @heading4
            (heading3) @heading3
            (heading2) @heading2
            (heading1) @heading1
            ]]

            -- Define the query for ranged_verbatim_tag
            local verbatim_query_string = [[
            (ranged_verbatim_tag
                name: (tag_name) @tag_name
                (tag_parameters
                  (tag_param) @tag_parameter))
            ]]

            -- Create the query object for headings and tags
            local heading_query = vim.treesitter.query.parse('norg', heading_query_string)
            local verbatim_query = vim.treesitter.query.parse('norg', verbatim_query_string)

            local node_tree = {}
            for _, node, _, _ in heading_query:iter_captures(tree:root(), bufnr, 0, -1) do
                local row1, _, row2, _ = node:range()
                if row1 < cursor_row and row2 >= cursor_row then
                    table.insert(node_tree, node)
                end
            end
            local is_ranged_verbatim = false
            local is_property = false
            local property_line = nil
            local heading_line = nil
            if #node_tree > 0 then
                heading_line, _, _, _ = node_tree[#node_tree]:range()
                heading_line = heading_line + 1
            end
            for child in node_tree[#node_tree]:iter_children() do
                local hrow1, _, _, _ = child:range()
                if child:type() == "ranged_verbatim_tag" then
                    for _, node, _, _ in verbatim_query:iter_captures(tree:root(), bufnr, 0, -1) do
                        local vrow1, _, _, _ = node:range()
                        if hrow1 == vrow1 then
                            local node_text = vim.treesitter.get_node_text(node, bufnr)
                            if node_text == "data" then
                                is_ranged_verbatim = true
                            else
                                is_property = true
                                property_line = vrow1 + 1
                            end
                        end
                    end
                end
            end
            if is_ranged_verbatim and is_property then
                return true, property_line, heading_line
            else
                return false, property_line, heading_line
            end
        end,

        -- Reads a specific line from a file
        read_line = function(file, line_number)
            local current_line = 0
            for line in file:lines() do
                current_line = current_line + 1
                if current_line == line_number then
                    return line
                end
            end
            return nil
        end,

        encode_metadata_text = function(metadata_text)
            local task_value = {}
            if metadata_text then
                for _, entry in ipairs(metadata_text) do
                    for line in string.gmatch(entry, "[^\r\n]+") do
                        local key, value = line:match("^%s*([^:]+):%s*(.*)")
                        if key == "started" or key == "completed" or key == "deadline" then
                            local year, month, day, hour, minute = string.match(value,
                                "(%d%d%d%d)%-(%d%d)%-(%d%d)|(%d%d):(%d%d)")
                            task_value[key] = {
                                year = year,
                                month = month,
                                day = day,
                                hour = hour,
                                minute = minute
                            }
                        elseif key == "tag" then
                            local tags = {}
                            for tag in string.gmatch(value, "%s*(%w+)%s*") do
                                table.insert(tags, tag)
                            end
                            task_value[key] = tags
                        else
                            task_value[key] = value
                        end
                    end
                end
            end
            return task_value
        end,

        -- Extracts agenda data from a file, starting from a specific line
        extract_property_metadata = function(filename, line_number)
            local file = io.open(filename, "r")
            if not file then
                vim.notify("Error opening file: " .. filename, vim.log.levels.ERROR)
                return nil
            end

            local next_line = module.public["meta-man"].read_line(file, line_number + 1)
            local agenda_lines = nil
            if next_line and string.match(next_line, "@data property") then
                agenda_lines = {}
                for line in file:lines() do
                    if string.match(line, "@end") then
                        break
                    end
                    table.insert(agenda_lines, line)
                end
                file:close()
            else
                file:close()
            end
            return module.public["meta-man"].encode_metadata_text(agenda_lines)
        end,

        push_new_property_metadata_string = function(row, props)
            local bufnr = vim.api.nvim_get_current_buf()
            local text = {}

            table.insert(text, "@data property")
            for key, value in pairs(props) do
                table.insert(text, key .. ": " .. value)
            end
            table.insert(text, "@end")

            local push_text = table.concat(text, "\n")
            local lines = vim.split(push_text, "\n")
            vim.api.nvim_buf_set_lines(bufnr, row, row, false, lines)
            vim.cmd(string.format("%d,%dnormal! ==", row + 1, row + #lines))
        end,

        delete_property_metadata = function(row, bufnr)
            local total_lines = vim.api.nvim_buf_line_count(bufnr)

            for i = row, total_lines do
                local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
                if line:match("@end") then
                    vim.api.nvim_buf_set_lines(bufnr, row, i, false, {})
                    break
                end
            end
        end,

        fetch_updated_property_metadata = function(prop_table)
            local fields = { started = false, completed = false, deadline = false, tag = false, priority = false }
            if prop_table ~= nil then
                for key, value in pairs(prop_table) do
                    -- Mark field as true if value is nil
                    if value == nil then
                        fields[key] = true
                        goto continue
                    end
                    -- Mark field as true if value is an empty table
                    if type(value) == "table" and next(value) == nil then
                        fields[key] = true
                        goto continue
                    end
                    -- Mark field as true if value is an empty string
                    if value == "" then
                        fields[key] = true
                    end
                    ::continue::
                end

                local prop_string = {}
                for key, value in pairs(fields) do
                    if key == "started" or key == "deadline" or key == "completed" then
                        if value or not prop_table[key] then
                            vim.ui.input({ prompt = "Enter " .. key .. " date-time (YYYY-MM-DD|HH:MM): " },
                                function(input)
                                    if input ~= "" then
                                        prop_string[key] = input
                                    end
                                end)
                        else
                            local text = prop_table[key].year ..
                                "-" ..
                                prop_table[key].month ..
                                "-" ..
                                prop_table[key].day .. "|" .. prop_table[key].hour .. ":" .. prop_table[key].minute
                            vim.ui.input(
                                { prompt = "Enter " .. key .. " date-time (YYYY-MM-DD|HH:MM): ", default = text },
                                function(input)
                                    if input ~= "" then
                                        prop_string[key] = input
                                    end
                                end)
                        end
                    elseif key == "tag" then
                        if value or not prop_table[key] then
                            vim.ui.input({ prompt = "Enter comma-separated tags (tag1, tag2, ...): " }, function(input)
                                if input ~= "" then
                                    prop_string[key] = input
                                end
                            end)
                        else
                            local tags = table.concat(prop_table[key], ", ")
                            vim.ui.input({ prompt = "Enter comma-separated tags (tag1, tag2, ...): ", default = tags },
                                function(input)
                                    if input ~= "" then
                                        prop_string[key] = input
                                    end
                                end)
                        end
                    else
                        if value or not prop_table[key] then
                            vim.ui.input({ prompt = "Enter priority (A/B/C/...): " }, function(input)
                                if input ~= "" then
                                    prop_string[key] = input
                                end
                            end)
                        else
                            vim.ui.input({ prompt = "Enter priority (A/B/C/...): ", default = prop_table[key] },
                                function(input)
                                    if input ~= "" then
                                        prop_string[key] = input
                                    end
                                end)
                        end
                    end
                end
                return prop_string
            end
            return {}
        end,

        generate_property_metadata = function()
            local prop_table = {}
            local started = vim.fn.input("Enter started date-time (YYYY-MM-DD|HH:MM): ")
            local deadline = vim.fn.input("Enter deadline date-time (YYYY-MM-DD|HH:MM): ")
            local completed = vim.fn.input("Enter completed date-time (YYYY-MM-DD|HH:MM): ")
            local tag = vim.fn.input("Enter comma-separated tags (tag1, tag2, ...): ")
            local priority = vim.fn.input("Enter priority (A/B/C/...): ")

            if started ~= "" then
                prop_table["started"] = started
            end
            if deadline ~= "" then
                prop_table["deadline"] = deadline
            end
            if completed ~= "" then
                prop_table["completed"] = completed
            end
            if tag ~= "" then
                prop_table["tag"] = tag
            end
            if priority ~= "" then
                prop_table["priority"] = priority
            end

            return prop_table
        end,

        update_property_metadata = function()
            local bufnr = vim.api.nvim_get_current_buf()
            local cursor_pos = vim.api.nvim_win_get_cursor(0)
            local full_path = vim.api.nvim_buf_get_name(0)
            -- Create a new floating window with the same buffer
            local opts = {
                relative = "cursor",
                width = 1,
                height = 1,
                row = 1,
                col = 0,
                style = "minimal",
                focusable = false,
            }
            local win = vim.api.nvim_open_win(bufnr, true, opts)
            vim.api.nvim_win_set_cursor(win, { cursor_pos[1] + 1, 0 })

            -- Check if there is property metadata
            local value, property_line, heading_line = module.public["meta-man"].is_present_property_metadata(bufnr)

            vim.api.nvim_win_close(win, true)
            vim.api.nvim_win_set_cursor(0, cursor_pos)
            if value then
                local prop_table = module.public["meta-man"].extract_property_metadata(full_path, heading_line)
                local prop_string = module.public["meta-man"].fetch_updated_property_metadata(prop_table)
                module.public["meta-man"].delete_property_metadata(heading_line, bufnr)
                module.public["meta-man"].push_new_property_metadata_string(heading_line, prop_string)
            else
                local prop_table = module.public["meta-man"].generate_property_metadata()
                module.public["meta-man"].push_new_property_metadata_string(heading_line, prop_table)
            end
        end,

        -- Function to extract metadata from a Neorg file.
        -- This function reads the entire content of a Neorg file and attempts to extract
        -- the metadata block defined between "@document.meta" and "@end". If the metadata
        -- is found, it decodes the metadata into a table; otherwise, it returns nil.
        extract_file_metadata = function(norg_address)
            local file = io.open(norg_address, "r")
            if not file then
                print("Could not open file: " .. norg_address)
                return nil
            end

            local content = file:read("*all")
            file:close()

            -- Search for the metadata block within the file content
            local metadata_block = content:match("@document%.meta(.-)@end")
            if not metadata_block then
                print("No metadata found in file: " .. norg_address)
                return nil
            end

            local metadata = {}
            local in_categories = false
            local categories = {}

            -- Iterate through each line of the metadata block
            for line in metadata_block:gmatch("[^\r\n]+") do
                if in_categories then
                    if line:match("%]") then
                        in_categories = false
                        metadata["categories"] = categories
                        categories = {}
                    else
                        table.insert(categories, line:match("%s*(.-)%s*$"))
                    end
                else
                    local key, value = line:match("^%s*(%w+):%s*(.-)%s*$")
                    if key and value then
                        if key == "categories" then
                            in_categories = true
                            local initial_values = value:match("%[(.-)%]")
                            if initial_values then
                                for item in initial_values:gmatch("[^,%s]+") do
                                    table.insert(categories, item)
                                end
                                in_categories = false
                                metadata["categories"] = categories
                                categories = {}
                            end
                        else
                            metadata[key] = value
                        end
                    end
                end
            end
            return metadata
        end
    },

    -- Gets stuff done
    ["task-man"] = {
        -- Define state mappings
        state_to_symbol_mapping = {
            done = "x",
            cancelled = "_",
            pending = "-",
            hold = "=",
            undone = " ",
            important = "!",
            recurring = "+",
            ambiguous = "?"
        },

        symbol_to_icon_mapping = {
            ["x"] = "󰄬",
            ["_"] = "",
            ["-"] = "󰥔",
            ["="] = "",
            [" "] = "×",
            ["!"] = "⚠",
            ["+"] = "↺",
            ["?"] = "",
        },

        blacklist_states = function(input_list)
            local filtered_state_icons = {}
            for state, symbol in pairs(module.public["task-man"].state_to_symbol_mapping) do
                if not vim.tbl_contains(input_list, state) then
                    filtered_state_icons[symbol] = module.public["task-man"].symbol_to_icon_mapping[symbol]
                end
            end
            return filtered_state_icons
        end,

        find_tasks_in_workspace = function(base_directory)
            local rg_command = [[rg '^\*{1,8} \(\s*(-?)\s*x*\?*!*_*\+*=*\)' --glob '*.norg' --line-number ]] ..
                base_directory
            return vim.fn.systemlist(rg_command)
        end,

        parse_task_line = function(line)
            local file, lnum, text = line:match("([^:]+):(%d+):(.*)")
            local task_state = text:match("%((.)%)")
            return file, tonumber(lnum), text, task_state
        end,

        add_agenda_data = function(task)
            local agenda_data = module.public["meta-man"].extract_property_metadata(task.filename, task.lnum)
            if agenda_data then
                for key, value in pairs(agenda_data) do
                    task[key] = value
                end
            end
            return task
        end,

        filter_tasks = function(input_list)
            local blacklisted_state_icons = module.public["task-man"].blacklist_states(input_list)
            local base_directory = module.required["core.dirman"].get_current_workspace()[2]
            local lines = module.public["task-man"].find_tasks_in_workspace(base_directory)

            -- Filter and map tasks
            local task_list = {}
            for _, line in ipairs(lines) do
                local file, lnum, text, task_state_symbol = module.public["task-man"].parse_task_line(line)
                if not blacklisted_state_icons[task_state_symbol] and file and lnum and text then
                    local task = {
                        state = module.public["task-man"].symbol_to_icon_mapping[task_state_symbol],
                        filename = file,
                        lnum = lnum,
                        task = text,
                    }
                    table.insert(task_list, module.public["task-man"].add_agenda_data(task))
                end
            end

            return task_list
        end

    },

    -- Too stronk!
    ["buff-man"] = {
        buf = nil,
        win = nil,
        default_winopts = {
            { "wrap",           nil },
            { "conceallevel",   nil },
            { "number",         nil },
            { "relativenumber", nil },
        },

        --- Navigates to a specific task in a Neorg file and opens it at the correct line.
        --- Parses the current Neorg link under the cursor, finds the corresponding task
        --- in the target file using `ripgrep`, and opens the file at the task's line.
        open_to_target_task = function()
            -- Wrapping around the esupports.hop module to get the link
            local parsed_link = neorg.modules.get_module("core.esupports.hop").parse_link(
                module.required["core.esupports.hop"].extract_link_node(),
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
            vim.api.nvim_buf_delete(module.public["buff-man"].buf, { force = true })
            -- Populate the default_winopts table with current window options
            for _, opt in ipairs(module.public["buff-man"].default_winopts) do
                vim.api.nvim_set_option_value(opt[1], opt[2], { win = module.public["buff-man"].win })
            end
        end,

        --- Standard buffer to display agendas
        ---@param buffer_lines string[]
        ---@return integer buffer_number
        ---@return integer window_number
        create_view_buffer = function(buffer_lines)
            module.public["buff-man"].buf = vim.api.nvim_create_buf(true, true)

            module.public["buff-man"].win = vim.api.nvim_get_current_win()
            vim.api.nvim_win_set_buf(module.public["buff-man"].win, module.public["buff-man"].buf)
            vim.api.nvim_buf_set_lines(module.public["buff-man"].buf, 0, -1, false, buffer_lines)

            -- Populate the default_winopts table with current window options
            for _, opt in ipairs(module.public["buff-man"].default_winopts) do
                opt[2] = vim.api.nvim_get_option_value(opt[1], { win = module.public["buff-man"].win })
            end

            -- Set buffer options for display and interaction
            vim.api.nvim_set_option_value("filetype", "norg", { buf = module.public["buff-man"].buf })
            vim.api.nvim_set_option_value("modifiable", false, { buf = module.public["buff-man"].buf })
            vim.api.nvim_set_option_value('swapfile', false, { buf = module.public["buff-man"].buf })
            vim.api.nvim_set_option_value('buftype', 'nofile', { buf = module.public["buff-man"].buf })
            vim.api.nvim_set_option_value('bufhidden', 'delete', { buf = module.public["buff-man"].buf })
            vim.api.nvim_set_option_value("readonly", true, { buf = module.public["buff-man"].buf })
            vim.api.nvim_set_option_value("wrap", false, { win = module.public["buff-man"].win })
            vim.api.nvim_set_option_value("conceallevel", 2, { win = module.public["buff-man"].win })
            vim.api.nvim_set_option_value("number", false, { win = module.public["buff-man"].win })
            vim.api.nvim_set_option_value("relativenumber", false, { win = module.public["buff-man"].win })

            vim.api.nvim_buf_set_keymap(module.public["buff-man"].buf, 'n', '<cr>', '', {
                noremap = true,
                silent = true,
                callback = module.public["buff-man"].open_to_target_task
            })
            vim.api.nvim_buf_set_keymap(module.public["buff-man"].buf, 'n', 'q', '', {
                noremap = true,
                silent = true,
                callback = function()
                    -- Restore the original window options when closing
                    for _, opt in ipairs(module.public["buff-man"].default_winopts) do
                        vim.api.nvim_set_option_value(opt[1], opt[2], { win = module.public["buff-man"].win })
                    end
                    vim.api.nvim_buf_delete(module.public["buff-man"].buf, { force = true })
                end
            })

            return module.public["buff-man"].buf, module.public["buff-man"].win
        end
    }
}

return module