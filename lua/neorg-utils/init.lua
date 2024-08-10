local telescopic = require("neorg-utils.telescopic")
local agenda = require("neorg-utils.neorg-agenda")
local utils = require("neorg-utils.utils")

local neorg_utils = {
    telescopic = telescopic,
    agenda = agenda,
    utils = utils
}

neorg_utils.setup = function(opts)
    -- Do something    
end

require("telescope").load_extension("neorg_workspace_selector")
require("telescope").load_extension("neorg_node_injector")
require("telescope").load_extension("neorg_show_backlinks")
require("telescope").load_extension("neorg_block_injector")

return neorg_utils
