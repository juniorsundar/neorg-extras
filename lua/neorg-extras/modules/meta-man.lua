local M = {}

function M.is_present_property_metadata(bufnr)
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
end

-- Reads a specific line from a file
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

function M.encode_metadata_text(metadata_text)
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
end

-- Extracts agenda data from a file, starting from a specific line
function M.extract_property_metadata(filename, line_number)
    local file = io.open(filename, "r")
    if not file then
        vim.notify("Error opening file: " .. filename, vim.log.levels.ERROR)
        return nil
    end

    local next_line = read_line(file, line_number + 1)
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
    return M.encode_metadata_text(agenda_lines)
end

function M.push_new_property_metadata_string(row, props)
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
end

function M.delete_property_metadata(row, bufnr)
    local total_lines = vim.api.nvim_buf_line_count(bufnr)

    for i = row, total_lines do
        local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
        if line:match("@end") then
            vim.api.nvim_buf_set_lines(bufnr, row, i, false, {})
            break
        end
    end
end

function M.fetch_updated_property_metadata(prop_table)
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
                    vim.ui.input({ prompt = "Enter " .. key .. " date-time (YYYY-MM-DD|HH:MM): " }, function(input)
                        if input ~= "" then
                            prop_string[key] = input
                        end
                    end)
                else
                    local text = prop_table[key].year ..
                    "-" ..
                    prop_table[key].month ..
                    "-" .. prop_table[key].day .. "|" .. prop_table[key].hour .. ":" .. prop_table[key].minute
                    vim.ui.input({ prompt = "Enter " .. key .. " date-time (YYYY-MM-DD|HH:MM): ", default = text },
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
                    vim.ui.input({ prompt = "Enter priority (A/B/C/...): ", default = prop_table[key] }, function(input)
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
end

function M.generate_property_metadata()
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
end

function M.update_property_metadata()
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
    local value, property_line, heading_line = M.is_present_property_metadata(bufnr)

    vim.api.nvim_win_close(win, true)
    vim.api.nvim_win_set_cursor(0, cursor_pos)
    if value then
        local prop_table = M.extract_property_metadata(full_path, heading_line)
        local prop_string = M.fetch_updated_property_metadata(prop_table)
        M.delete_property_metadata(heading_line, bufnr)
        M.push_new_property_metadata_string(heading_line, prop_string)
    else
        local prop_table = M.generate_property_metadata()
        M.push_new_property_metadata_string(heading_line, prop_table)
    end
end

-- Function to extract metadata from a Neorg file.
-- This function reads the entire content of a Neorg file and attempts to extract
-- the metadata block defined between "@document.meta" and "@end". If the metadata
-- is found, it decodes the metadata into a table; otherwise, it returns nil.
function M.extract_file_metadata(norg_address)
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

return M
