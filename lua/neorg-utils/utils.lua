local M = {}

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

    -- Map 'q' to close the tab
    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':tabclose<CR>', { noremap = true, silent = true })


    return buf, win
end

function M.inject_prop_metadata()
    return [[
        @data property
        id:
        started:
        completed:
        deadline:
        tag:
        priority:
        @end
        ]]
end

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
        heading_line = node_tree[#node_tree]:range() + 1
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


function M.update_prop_metadata()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor_pos = vim.api.nvim_win_get_cursor(0)

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
        vim.notify(tostring(value) .. "-" .. property_line .. "-" .. heading_line)
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
