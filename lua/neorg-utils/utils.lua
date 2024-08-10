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

    -- Map 'q' to close the tab
    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':tabclose<CR>', { noremap = true, silent = true })


    return buf, win
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
