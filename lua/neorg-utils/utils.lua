local M = {}

function M.extract_file_metadata(norg_address)
    -- Read the entire file content
    local file = io.open(norg_address, "r")
    if not file then
        print("Could not open file: " .. norg_address)
        return nil
    end
    local content = file:read("*all")
    file:close()

    -- Extract metadata block
    local metadata_block = content:match("@document%.meta(.-)@end")
    if not metadata_block then
        print("No metadata found in file: " .. norg_address)
        return nil
    end

    return M.decode_metadata(metadata_block)
end

function M.decode_metadata(metadata_block)
    -- Parse metadata block into a table
    local metadata = {}
    local in_categories = false
    local categories = {}

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
