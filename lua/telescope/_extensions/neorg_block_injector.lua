local telescopic = require("neorg-extras.telescopic")

return require("telescope").register_extension({
    exports = {
        neorg_block_injector = telescopic.neorg_block_injector,
    }
})
