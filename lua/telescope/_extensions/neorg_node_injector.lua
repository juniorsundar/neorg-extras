local telescopic = require("neorg-utils.telescopic")

return require("telescope").register_extension({
    exports = {
        neorg_node_injector = telescopic.neorg_node_injector,
    }
})

