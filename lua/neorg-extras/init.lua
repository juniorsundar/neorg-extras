local agenda = require("neorg-extras.neorg-agenda")
local meta_man = require("neorg-extras.modules.meta-man")

local neorg_utils = {
    agenda = agenda,
}

neorg_utils.setup = function(opts)
    opts = opts or {}

    opts.treesitter_fold = opts.treesitter_fold ~= false

    if opts.treesitter_fold then
        meta_man.setup_treesitter_folding()
    end

    -- Load Telescope extensions
    require("telescope").load_extension("neorg_workspace_selector")
    require("telescope").load_extension("neorg_node_injector")
    require("telescope").load_extension("neorg_show_backlinks")
    require("telescope").load_extension("neorg_block_injector")
end

return neorg_utils
