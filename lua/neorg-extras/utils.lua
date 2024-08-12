local M = {}

local function is_prop_metadata(bufnr)
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

local function encode_metadata_text(metadata_text)
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
function M.extract_property_data(filename, line_number)
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
    return encode_metadata_text(agenda_lines)
end

function M.create_buffer(buffer_lines)
    -- Create a new buffer for displaying the agenda
    local buf = vim.api.nvim_create_buf(false, true)

    -- Open the buffer in a new tab and configure the buffer options
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
        local file = vim.api.nvim_buf_get_name(0)  -- Get current buffer's file name
        local row, _ = unpack(vim.api.nvim_win_get_cursor(0))  -- Get current cursor position

        vim.cmd("tabclose")  -- Close current tab

        -- Reopen the file in the previous tab
        vim.cmd("tabprevious")  -- Go back to the previous tab
        vim.cmd("edit " .. file)  -- Open the file
        vim.api.nvim_win_set_cursor(0, {row, 0})  -- Restore the cursor position
    end

    -- Setup an autocommand to observe buffer changes and trigger the function
    vim.api.nvim_create_autocmd("BufLeave", {
        buffer = buf,
        callback = on_buf_leave,
        once = true,  -- Only trigger once
    })

    return buf, win
end

local function push_new_property_text(row, props)
    local bufnr = vim.api.nvim_get_current_buf()
    local text = {}

    -- Add the initial @data property line with the row number
    table.insert(text, "@data property")
    for key, value in pairs(props) do
        table.insert(text, key .. ": " .. value)
    end
    table.insert(text, "@end")

    -- Combine all parts into a single string with new lines + autoindent
    local push_text = table.concat(text, "\n")
    local lines = vim.split(push_text, "\n")
    vim.api.nvim_buf_set_lines(bufnr, row, row, false, lines)
    vim.cmd(string.format("%d,%dnormal! ==", row + 1, row + #lines))
end

local function delete_property_metadata_block(row, bufnr)
    local total_lines = vim.api.nvim_buf_line_count(bufnr)

    for i = row, total_lines do
        local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
        if line:match("@end") then
            vim.api.nvim_buf_set_lines(bufnr, row, i, false, {})
            break
        end
    end
end

local function update_old_property_metadata(prop_table)
    local fields = { started = false, completed = false, deadline = false, tag = false, priority = false }
    if prop_table ~= nil then
        for key, value in pairs(prop_table) do
            if value == nil or value == "" or next(value) == nil then
                fields[key] = true
            end
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

local function generate_new_prop_metadata()
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

function M.update_prop_metadata()
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
    local value, property_line, heading_line = is_prop_metadata(bufnr)

    vim.api.nvim_win_close(win, true)
    vim.api.nvim_win_set_cursor(0, cursor_pos)
    if value then
        local prop_table = M.extract_property_data(full_path, heading_line)
        local prop_string = update_old_property_metadata(prop_table)
        delete_property_metadata_block(heading_line, bufnr)
        push_new_property_text(heading_line, prop_string)
    else
        local prop_table = generate_new_prop_metadata()
        push_new_property_text(heading_line, prop_table)
    end
end

-- Function to extract metadata from a Neorg file.
-- This function reads the entire content of a Neorg file and attempts to extract
-- the metadata block defined between "@document.meta" and "@end". If the metadata
-- is found, it decodes the metadata into a table; otherwise, it returns nil.
function M.extract_file_metadata(norg_address)
    -- Open the Neorg file for reading
    local file = io.open(norg_address, "r")
    if not file then
        print("Could not open file: " .. norg_address)
        return nil
    end

    -- Read the entire file content into a string
    local content = file:read("*all")
    file:close()

    -- Search for the metadata block within the file content
    local metadata_block = content:match("@document%.meta(.-)@end")
    if not metadata_block then
        print("No metadata found in file: " .. norg_address)
        return nil
    end

    -- Decode the metadata block into a table and return it
    return M.decode_metadata(metadata_block)
end

-- Function to decode the metadata block into a table.
-- This function parses the metadata block line by line, converting key-value pairs
-- into a Lua table. It also handles special cases, such as parsing categories
-- enclosed in square brackets.
function M.decode_metadata(metadata_block)
    -- Initialize the metadata table
    local metadata = {}
    local in_categories = false
    local categories = {}

    -- Iterate through each line of the metadata block
    for line in metadata_block:gmatch("[^\r\n]+") do
        -- Check if currently parsing categories
        if in_categories then
            if line:match("%]") then
                -- End of categories
                in_categories = false
                metadata["categories"] = categories
                categories = {}
            else
                -- Add category item to the list
                table.insert(categories, line:match("%s*(.-)%s*$"))
            end
        else
            -- Parse key-value pairs from the line
            local key, value = line:match("^%s*(%w+):%s*(.-)%s*$")
            if key and value then
                if key == "categories" then
                    -- Start of categories block
                    in_categories = true
                    local initial_values = value:match("%[(.-)%]")
                    if initial_values then
                        -- Parse initial categories within the same line
                        for item in initial_values:gmatch("[^,%s]+") do
                            table.insert(categories, item)
                        end
                        in_categories = false
                        metadata["categories"] = categories
                        categories = {}
                    end
                else
                    -- Regular key-value pair
                    metadata[key] = value
                end
            end
        end
    end
    return metadata
end

return M
