local telescopic = require("neorg-utils.telescopic")

return require("telescope").register_extension({
    exports = {
        neorg_block_injector = telescopic.neorg_block_injector,
    }
})
