local telescopic = require("neorg-utils.telescopic")
local agenda = require("neorg-utils.neorg-agenda")
local utils = require("neorg-utils.utils")

require("telescope").load_extension("neorg_workspace_selector")
require("telescope").load_extension("neorg_node_injector")
require("telescope").load_extension("neorg_show_backlinks")
require("telescope").load_extension("neorg_block_injector")

return {
    telescopic = telescopic,
    agenda = agenda,
    utils = utils
}
