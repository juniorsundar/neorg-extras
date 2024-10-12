local neorg = require("neorg.core")
local module = neorg.modules.create("external.roam")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.neorgcmd",
            "core.dirman",
            "core.integrations.treesitter",
            "external.many-mans",
        },
    }
end

module.config.public = {
    fuzzy_finder = "Telescope" -- or "Fzf"
}

module.load = function()
    module.required["core.neorgcmd"].add_commands_from_table({
        ["roam"] = {
            args = 1,
            subcommands = {
                ["node"] = {
                    min_args = 0,
                    name = "external.roam.node",
                },
                ["block"] = {
                    args = 0,
                    name = "external.roam.block",
                },
                ["backlinks"] = {
                    args = 0,
                    name = "external.roam.backlinks",
                },
                ["select_workspace"] = {
                    args = 0,
                    name = "external.roam.select_workspace",
                },
            },
        },
    })
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["external.roam.node"] = true,
        ["external.roam.block"] = true,
        ["external.roam.backlinks"] = true,
        ["external.roam.select_workspace"] = true,
    },
}

module.private = {

    get_fuzzy_finder_modules = function()
        if module.config.public.fuzzy_finder == "Telescope" then
            local success, _ = pcall(require, "telescope")
            if not success then
                return false
            end

            module.private.telescope_modules = {
                pickers = require("telescope.pickers"),
                finders = require("telescope.finders"),
                conf = require("telescope.config").values, -- Allows us to use the values from the user's config
                make_entry = require("telescope.make_entry"),
                actions = require("telescope.actions"),
                actions_set = require("telescope.actions.set"),
                state = require("telescope.actions.state"),
            }
            return true
        elseif module.config.public.fuzzy_finder == "Fzf" then
            local success, fzf_lua = pcall(require, "fzf-lua")
            if not success then
                return false
            end

            module.private.fzf_modules = {
                fzf_lua = fzf_lua,
                previewer = require("fzf-lua.previewer"),
                builtin_previewer = require("fzf-lua.previewer.builtin"),
                actions = require("fzf-lua.actions"),
            }
            return true
        else
            return false
        end
    end,

    ---@param filename string
    ---@param lineno number?
    ---@return string|nil
    get_heading_text = function(filename, lineno)
        local file = io.open(filename, "r")
        if not file then
            print("Cannot open file:", filename)
            return nil
        end

        local file_content = file:read("*all")
        file:close()

        local tree = vim.treesitter.get_string_parser(file_content, "norg"):parse()[1]
        local heading_query_string = [[
        (heading1
          title: (paragraph_segment) @paragraph_segment
        ) @heading1

        (heading2
          title: (paragraph_segment) @paragraph_segment
        ) @heading2

        (heading3
          title: (paragraph_segment) @paragraph_segment
        ) @heading3

        (heading4
          title: (paragraph_segment) @paragraph_segment
        ) @heading4

        (heading5
          title: (paragraph_segment) @paragraph_segment
        ) @heading5

        (heading6
          title: (paragraph_segment) @paragraph_segment
        ) @heading6
        ]]

        local heading_query = vim.treesitter.query.parse("norg", heading_query_string)
        local target_line = lineno - 1
        for _, node, _, _ in heading_query:iter_captures(tree:root(), file_content, 0, -1) do
            local row1, _, row2, _ = node:range()
            if row1 < lineno and row2 >= target_line then
                for child in node:iter_children() do
                    local crow1, _, crow2, _ = child:range()
                    if child:type() == "paragraph_segment" and (crow1 < lineno and crow2 >= target_line) then
                        return (vim.treesitter.get_node_text(child, file_content))
                    end
                end
            end
        end
        return nil
    end,
}

module.public = {
    -- Function to find and insert nodes from Neorg files.
    -- This function scans Neorg files in the current workspace and allows the user to either insert
    -- a selected node into the current buffer or create a new node.
    node = function()
        local fuzzy = module.private.get_fuzzy_finder_modules()
        if not fuzzy then
            vim.notify("No fuzzy finder present.", vim.log.levels.ERROR)
            return nil
        end

        local current_workspace = module.required["core.dirman"].get_current_workspace()
        local base_directory = current_workspace[2]

        if module.config.public.fuzzy_finder == "Telescope" then
            -- Find all .norg files in the workspace
            local norg_files_output = vim.fn.systemlist("fd -e norg --type f --base-directory " .. base_directory)

            -- Extract titles and paths from the Neorg files
            local title_path_pairs = {}
            for _, line in pairs(norg_files_output) do
                local full_path = base_directory .. "/" .. line
                local metadata = module.required["external.many-mans"]["meta-man"].extract_file_metadata(full_path)
                if metadata ~= nil then
                    table.insert(title_path_pairs, { metadata["title"], full_path })
                else
                    table.insert(title_path_pairs, { "Untitled", full_path })
                end
            end

            local opts = {}
            opts.entry_maker = opts.entry_maker or module.private.telescope_modules.make_entry.gen_from_file(opts)

            -- Set up Telescope picker to display and select Neorg files
            module.private.telescope_modules.pickers
                .new(opts, {
                    prompt_title = "Find Neorg Node",
                    finder = module.private.telescope_modules.finders.new_table({
                        results = title_path_pairs,
                        entry_maker = function(entry)
                            return {
                                value = entry[2],
                                display = entry[1],
                                ordinal = entry[1],
                            }
                        end,
                    }),
                    previewer = module.private.telescope_modules.conf.file_previewer(opts),
                    sorter = module.private.telescope_modules.conf.file_sorter(opts),
                    attach_mappings = function(prompt_bufnr, map)
                        -- Map <C-i> to insert the selected node into the current buffer
                        map("i", "<C-i>", function()
                            local entry = module.private.telescope_modules.state.get_selected_entry()
                            local current_file_path = entry.value
                            local escaped_base_path = base_directory:gsub("([^%w])", "%%%1")
                            local relative_path = current_file_path:match("^" .. escaped_base_path .. "/(.+)%..+")
                            -- Insert at the cursor location
                            module.private.telescope_modules.actions.close(prompt_bufnr)
                            vim.api.nvim_put({ "{:$/" .. relative_path .. ":}[" .. entry.display .. "]" }, "", false,
                                true)
                        end)

                        -- Map <C-n> to create a new node with the given title in the default note vault
                        map("i", "<C-n>", function()
                            local prompt = module.private.telescope_modules.state.get_current_line()
                            local title_token = prompt:gsub("%W", ""):lower()
                            local n = #title_token
                            if n > 5 then
                                local step = math.max(1, math.floor(n / 5))
                                local condensed = ""
                                for i = 1, n, step do
                                    condensed = condensed .. title_token:sub(i, i)
                                end
                                title_token = condensed
                            end
                            module.private.telescope_modules.actions.close(prompt_bufnr)

                            -- Ensure the vault directory exists
                            local vault_dir = base_directory .. "/vault/"
                            vim.fn.mkdir(vault_dir, "p")

                            -- Create and open a new Neorg file with the generated title token
                            vim.api.nvim_command("edit " ..
                                vault_dir .. os.date("%Y%m%d%H%M%S-") .. title_token .. ".norg")
                            vim.cmd([[Neorg inject-metadata]])

                            -- Update the title in the newly created buffer
                            local buf = vim.api.nvim_get_current_buf()
                            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                            for i, line in ipairs(lines) do
                                if line:match("^title:") then
                                    lines[i] = "title: " .. prompt
                                    break
                                end
                            end
                            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
                        end)
                        return true
                    end,
                })
                :find()
        elseif module.config.public.fuzzy_finder == "Fzf" then
            local titles = {}
            local title_path_dict = {}

            local norg_files_output = vim.fn.systemlist("fd -e norg --type f --base-directory " .. base_directory)

            -- Extract titles and paths from the Neorg files
            for _, line in pairs(norg_files_output) do
                local full_path = base_directory .. "/" .. line
                local metadata = module.required["external.many-mans"]["meta-man"].extract_file_metadata(full_path)
                if metadata ~= nil then
                    table.insert(titles, metadata["title"])
                    title_path_dict[metadata["title"]] = full_path
                else
                    table.insert(titles, full_path)
                    title_path_dict[full_path] = full_path
                end
            end

            local NodePreview = module.private.fzf_modules.builtin_previewer.buffer_or_file:extend()

            function NodePreview:new(o, opts, fzf_win)
                NodePreview.super.new(self, o, opts, fzf_win)
                setmetatable(self, NodePreview)
                return self
            end

            function NodePreview:parse_entry(entry_str)
                return {
                    path = title_path_dict[entry_str] == nil and entry_str or title_path_dict[entry_str],
                    line = 1,
                    col = 1,
                }
            end

            module.private.fzf_modules.fzf_lua.fzf_exec(titles, {
                previewer = NodePreview,
                prompt = "Find Neorg Node> ",
                actions = {
                    ["default"] = {
                        function(selected, _)
                            vim.cmd("new " .. title_path_dict[selected[1]])
                        end
                    },
                    ["ctrl-i"] = {
                        function(selected, _)
                            local current_file_path = title_path_dict[selected[1]]
                            local escaped_base_path = base_directory:gsub("([^%w])", "%%%1")
                            local relative_path = current_file_path:match("^" .. escaped_base_path .. "/(.+)%..+")
                            -- Insert after the cursor location
                            vim.cmd("q")
                            vim.api.nvim_put({ "{:$/" .. relative_path .. ":}[" .. selected[1] .. "]" }, "", true, true)
                        end
                    },
                    ["ctrl-n"] = {
                        function(_, opt)
                            -- Input query is in opt.__call_opts.query
                            local prompt = opt.__call_opts.query
                            local title_token = prompt:gsub("%W", ""):lower()
                            local n = #title_token
                            if n > 5 then
                                local step = math.max(1, math.floor(n / 5))
                                local condensed = ""
                                for i = 1, n, step do
                                    condensed = condensed .. title_token:sub(i, i)
                                end
                                title_token = condensed
                            end

                            -- Ensure the vault directory exists
                            local vault_dir = base_directory .. "/vault/"
                            vim.fn.mkdir(vault_dir, "p")

                            -- Create and open a new Neorg file with the generated title token
                            vim.cmd("new " .. vault_dir .. os.date("%Y%m%d%H%M%S-") .. title_token .. ".norg")
                            vim.cmd([[Neorg inject-metadata]])

                            -- Update the title in the newly created buffer
                            local buf = vim.api.nvim_get_current_buf()
                            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                            for i, line in ipairs(lines) do
                                if line:match("^title:") then
                                    lines[i] = "title: " .. prompt
                                    break
                                end
                            end
                            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
                        end
                    }
                }
            })
        end
    end,

    -- Function to find and insert blocks from Neorg files.
    -- This function searches for task blocks within Neorg files and allows the user to insert
    -- the selected block into the current buffer.
    block = function()
        local fuzzy = module.private.get_fuzzy_finder_modules()
        if not fuzzy then
            vim.notify("No fuzzy finder present.", vim.log.levels.ERROR)
            return nil
        end

        local current_workspace = module.required["core.dirman"].get_current_workspace()
        local base_directory = current_workspace[2]

        -- Define search pattern for different levels of task blocks
        local search_path = [["^\* |^\*\* |^\*\*\* |^\*\*\*\* |^\*\*\*\*\* |^\*\*\*\*\*\* "]]

        -- Run ripgrep to find matching lines in .norg files
        local rg_command = "rg " .. search_path .. " " .. "-g '*.norg' --with-filename --line-number " .. base_directory
        local rg_results = vim.fn.system(rg_command)

        if module.config.public.fuzzy_finder == "Telescope" then
            -- Process the ripgrep results
            local matches = {}
            local pattern = "([^:]+):(%d+):(.*)"
            for line in rg_results:gmatch("([^\n]+)") do
                local file, lineno, text = line:match(pattern)
                local metadata = module.required["external.many-mans"]["meta-man"].extract_file_metadata(file)
                if metadata ~= nil then
                    table.insert(matches, { file, lineno, text, metadata["title"] })
                else
                    table.insert(matches, { file, lineno, text, "Untitled" })
                end
            end

            local opts = {}
            opts.entry_maker = opts.entry_maker or module.private.telescope_modules.make_entry.gen_from_file(opts)

            -- Set up Telescope picker to display and select Neorg blocks
            module.private.telescope_modules.pickers
                .new(opts, {
                    prompt_title = "Find Block",
                    finder = module.private.telescope_modules.finders.new_table({
                        results = matches,
                        entry_maker = function(entry)
                            local filename = entry[1]
                            local line_number = tonumber(entry[2])
                            local text = tostring(entry[3])
                            local title = tostring(entry[4])

                            return {
                                value = filename,
                                display = title .. " | " .. text,
                                ordinal = title .. " | " .. text,
                                filename = filename,
                                lnum = line_number,
                                line = text,
                            }
                        end,
                    }),
                    previewer = module.private.telescope_modules.conf.grep_previewer(opts),
                    sorter = module.private.telescope_modules.conf.file_sorter(opts),
                    attach_mappings = function(prompt_bufnr, map)
                        -- Map <C-i> to insert the selected block into the current buffer
                        map("i", "<C-i>", function()
                            local entry = module.private.telescope_modules.state.get_selected_entry()
                            local filename = entry.filename
                            local base_path = base_directory:gsub("([^%w])", "%%%1")
                            local rel_path = filename:match("^" .. base_path .. "/(.+)%..+")
                            -- Insert at the cursor location
                            local heading_prefix = string.match(entry.line, "^(%** )")
                            local heading_text = module.private.get_heading_text(filename, entry.lnum)
                            if not heading_text then
                                return
                            else
                                heading_text = heading_text:gsub("^%s+", "")
                            end
                            local full_heading_text = heading_prefix .. heading_text

                            module.private.telescope_modules.actions.close(prompt_bufnr)
                            vim.api.nvim_put(
                                { "{:$/" .. rel_path .. ":" .. full_heading_text .. "}[" .. heading_text .. "]" },
                                "",
                                false,
                                true
                            )
                        end)
                        return true
                    end,
                })
                :find()
        elseif module.config.public.fuzzy_finder == "Fzf" then
            local text_string = {}
            local text_string_matches_dict = {}
            local pattern = "([^:]+):(%d+):(.*)"

            for line in rg_results:gmatch("([^\n]+)") do
                local file, lineno, text = line:match(pattern)
                local metadata = module.required["external.many-mans"]["meta-man"].extract_file_metadata(file)
                if metadata ~= nil then
                    table.insert(text_string, metadata["title"] .. " | " .. text)
                    text_string_matches_dict[metadata["title"] .. " | " .. text] = {
                        ["file"] = file,
                        ["line"] = lineno,
                        ["title"] = metadata["title"],
                        ["heading_text"] = text
                    }
                else
                    table.insert(text_string, file .. " | " .. text)
                    text_string_matches_dict[file .. " | " .. text] = {
                        ["file"] = file,
                        ["line"] = lineno,
                        ["title"] = file,
                        ["heading_text"] = text
                    }
                end
            end

            local BlockPreview = module.private.fzf_modules.builtin_previewer.buffer_or_file:extend()

            function BlockPreview:new(o, opts, fzf_win)
                BlockPreview.super.new(self, o, opts, fzf_win)
                setmetatable(self, BlockPreview)
                return self
            end

            function BlockPreview:parse_entry(entry_str)
                return {
                    path = text_string_matches_dict[entry_str] == nil and "/tmp/" or
                        text_string_matches_dict[entry_str]["file"],
                    line = text_string_matches_dict[entry_str] == nil and 1 or
                        text_string_matches_dict[entry_str]["line"],
                    col = 1,
                }
            end

            module.private.fzf_modules.fzf_lua.fzf_exec(text_string, {
                previewer = BlockPreview,
                prompt = "Find Neorg Block> ",
                actions = {
                    ["default"] = {
                        function(selected, _)
                            vim.cmd("new " .. text_string_matches_dict[selected[1]]["file"])
                            vim.cmd(":" .. text_string_matches_dict[selected[1]]["line"])
                        end
                    },
                    ["ctrl-i"] = {
                        function(selected, _)
                            local filename = text_string_matches_dict[selected[1]]["file"]
                            local base_path = base_directory:gsub("([^%w])", "%%%1")
                            local rel_path = filename:match("^" .. base_path .. "/(.+)%..+")

                            local heading_prefix = string.match(text_string_matches_dict[selected[1]]["heading_text"],
                                "^(%** )")
                            local heading_text = module.private.get_heading_text(filename,
                                tonumber(text_string_matches_dict[selected[1]]["line"]))
                            if not heading_text then
                                return
                            else
                                heading_text = heading_text:gsub("^%s+", "")
                            end
                            local full_heading_text = heading_prefix .. heading_text

                            vim.cmd("q")
                            vim.api.nvim_put(
                                { "{:$/" .. rel_path .. ":" .. full_heading_text .. "}[" .. heading_text .. "]" },
                                "",
                                true,
                                true)
                        end
                    },
                }
            })
        end
    end,

    -- Function to select and switch between Neorg workspaces.
    -- This function lists available workspaces and allows the user to switch to a selected workspace.
    workspace_selector = function()
        local fuzzy = module.private.get_fuzzy_finder_modules()
        if not fuzzy then
            vim.notify("No fuzzy finder present.", vim.log.levels.ERROR)
            return nil
        end

        local workspaces = module.required["core.dirman"].get_workspaces()
        local workspace_names = {}
        -- Collect the names of all workspaces
        for name in pairs(workspaces) do
            table.insert(workspace_names, name)
        end

        if module.config.public.fuzzy_finder == "Telescope" then
            local opts = {}
            opts.entry_maker = opts.entry_maker or module.private.telescope_modules.make_entry.gen_from_file(opts)

            -- Set up Telescope picker to display and select Neorg workspaces
            module.private.telescope_modules.pickers
                .new(opts, {
                    prompt_title = "Find Neorg Workspace",
                    finder = module.private.telescope_modules.finders.new_table({
                        results = workspace_names,
                        entry_maker = function(entry)
                            local filename = workspaces[entry] .. "/index.norg"

                            return {
                                value = filename,
                                display = entry,
                                ordinal = entry,
                                filename = filename,
                            }
                        end,
                    }),
                    previewer = module.private.telescope_modules.conf.file_previewer(opts),
                    sorter = module.private.telescope_modules.conf.file_sorter(opts),
                    attach_mappings = function(prompt_bufnr, map)
                        -- Map <CR> to switch to the selected workspace
                        map("i", "<CR>", function()
                            local entry = module.private.telescope_modules.state.get_selected_entry()
                            module.private.telescope_modules.actions.close(prompt_bufnr)
                            module.required["core.dirman"].set_workspace(tostring(entry.display))
                        end)
                        map("n", "<CR>", function()
                            local entry = module.private.telescope_modules.state.get_selected_entry()
                            module.private.telescope_modules.actions.close(prompt_bufnr)
                            module.required["core.dirman"].set_workspace(tostring(entry.display))
                        end)

                        return true
                    end,
                })
                :find()
        elseif module.config.public.fuzzy_finder == "Fzf" then
            local WorkspacePreview = module.private.fzf_modules.builtin_previewer.buffer_or_file:extend()

            function WorkspacePreview:new(o, opts, fzf_win)
                WorkspacePreview.super.new(self, o, opts, fzf_win)
                setmetatable(self, WorkspacePreview)
                return self
            end

            function WorkspacePreview:parse_entry(entry_str)
                return {
                    path = workspaces[entry_str] == nil and "/tmp/" or
                        workspaces[entry_str] .. "/index.norg",
                    line = 1,
                    col = 1,
                }
            end

            module.private.fzf_modules.fzf_lua.fzf_exec(workspace_names, {
                previewer = WorkspacePreview,
                prompt = "Find Neorg Workspace> ",
                actions = {
                    ["default"] = {
                        function(selected, _)
                            vim.cmd("new " .. workspaces[selected[1]] .. "/index.norg")
                            vim.cmd(":1")
                        end
                    },
                }
            })
        end
    end,

    -- Function to find and display backlinks to the current Neorg file.
    -- This function searches for references to the current file in other Neorg files and lists them.
    backlinks = function()
        local fuzzy = module.private.get_fuzzy_finder_modules()
        if not fuzzy then
            vim.notify("No fuzzy finder present.", vim.log.levels.ERROR)
            return nil
        end

        local current_workspace = module.required["core.dirman"].get_current_workspace()
        local base_directory = current_workspace[2]

        -- Get the path of the current file and convert it to a relative path within the workspace
        local current_file_path = vim.fn.expand("%:p")
        local escaped_base_path = base_directory:gsub("([^%w])", "%%%1")
        local relative_path = current_file_path:match("^" .. escaped_base_path .. "/(.+)%..+")
        if relative_path == nil then
            vim.notify("Current Node isn't a part of the Current Neorg Workspace", vim.log.levels.ERROR)
            return
        end
        local search_path = "{:$/" .. relative_path .. ":"

        -- Run ripgrep to find backlinks in other Neorg files
        local rg_command = "rg --fixed-strings "
        .. "'"
        .. search_path
        .. "'"
        .. " "
        .. "-g '*.norg' --with-filename --line-number "
        .. base_directory
        local rg_results = vim.fn.system(rg_command)

        -- Process the ripgrep results to identify backlinks
        local self_title =
        module.required["external.many-mans"]["meta-man"].extract_file_metadata(current_file_path)["title"]

        if module.config.public.fuzzy_finder == "Telescope" then
            local matches = {}
            for line in rg_results:gmatch("([^\n]+)") do
                local file, lineno = line:match("^(.-):(%d+):")
                local metadata = module.required["external.many-mans"]["meta-man"].extract_file_metadata(file)
                if metadata == nil then
                    table.insert(matches, { file, lineno, "Untitled" })
                elseif metadata["title"] ~= self_title then
                    table.insert(matches, { file, lineno, metadata["title"] })
                else
                    table.insert(matches, { file, lineno, "Untitled" })
                end
            end

            local opts = {}
            opts.entry_maker = opts.entry_maker or module.private.telescope_modules.make_entry.gen_from_file(opts)

            -- Set up Telescope picker to display and select backlinks
            module.private.telescope_modules.pickers
                .new(opts, {
                    prompt_title = "Backlinks",
                    finder = module.private.telescope_modules.finders.new_table({
                        results = matches,
                        entry_maker = function(entry)
                            local filename = entry[1]
                            local line_number = tonumber(entry[2])
                            local title = entry[3]

                            return {
                                value = filename,
                                display = title .. "  @" .. line_number,
                                ordinal = title,
                                filename = filename,
                                lnum = line_number,
                            }
                        end,
                    }),
                    previewer = module.private.telescope_modules.conf.grep_previewer(opts),
                    sorter = module.private.telescope_modules.conf.file_sorter(opts),
                })
                :find()
        elseif module.config.public.fuzzy_finder == "Fzf" then
            local backlink_texts = {}
            local backlink_text_matches_dict = {}
            for line in rg_results:gmatch("([^\n]+)") do
                local file, lineno = line:match("^(.-):(%d+):")
                local metadata = module.required["external.many-mans"]["meta-man"].extract_file_metadata(file)
                if metadata == nil then
                    table.insert(backlink_texts, "Untitled @" .. lineno)
                    backlink_text_matches_dict["Untitled @" .. lineno] = { ["file"] = file, ["line"] = lineno }
                elseif metadata["title"] ~= self_title then
                    table.insert(backlink_texts, metadata["title"] .. " @" .. lineno)
                    backlink_text_matches_dict[metadata["title"] .. " @" .. lineno] = { ["file"] = file, ["line"] =
                        lineno }
                else
                    table.insert(backlink_texts, "Untitled @" .. lineno)
                    backlink_text_matches_dict["Untitled @" .. lineno] = { ["file"] = file, ["line"] = lineno }
                end
            end

            local BacklinksPreview = module.private.fzf_modules.builtin_previewer.buffer_or_file:extend()

            function BacklinksPreview:new(o, opts, fzf_win)
                BacklinksPreview.super.new(self, o, opts, fzf_win)
                setmetatable(self, BacklinksPreview)
                return self
            end

            function BacklinksPreview:parse_entry(entry_str)
                return {
                    path = backlink_text_matches_dict[entry_str] == nil and "/tmp/" or
                        backlink_text_matches_dict[entry_str]['file'],
                    line = backlink_text_matches_dict[entry_str] == nil and 1 or
                        backlink_text_matches_dict[entry_str]['line'],
                    col = 1,
                }
            end

            module.private.fzf_modules.fzf_lua.fzf_exec(backlink_texts, {
                previewer = BacklinksPreview,
                prompt = "Backlinks> ",
                actions = {
                    ["default"] = {
                        function(selected, _)
                            vim.cmd("new " .. backlink_text_matches_dict[selected[1]]['file'])
                            vim.cmd(":" .. backlink_text_matches_dict[selected[1]]['line'])
                        end
                    },
                }
            })
        end
    end,
}

module.on_event = function(event)
    if event.split_type[2] == "external.roam.node" then
        module.public.node()
    elseif event.split_type[2] == "external.roam.block" then
        module.public.block()
    elseif event.split_type[2] == "external.roam.backlinks" then
        module.public.backlinks()
    elseif event.split_type[2] == "external.roam.select_workspace" then
        module.public.workspace_selector()
    end
end

return module
