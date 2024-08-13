local agenda = require("neorg-extras.neorg-agenda")

local neorg_utils = {
    agenda = agenda,
}

neorg_utils.setup = function(opts)
    -- Do something    
end

require("telescope").load_extension("neorg_workspace_selector")
require("telescope").load_extension("neorg_node_injector")
require("telescope").load_extension("neorg_show_backlinks")
require("telescope").load_extension("neorg_block_injector")

return neorg_utils
