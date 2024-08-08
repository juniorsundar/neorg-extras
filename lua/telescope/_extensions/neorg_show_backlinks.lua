local telescopic = require("neorg-utils.telescopic")

return require("telescope").register_extension({
    exports = {
        show_backlinks = telescopic.show_backlinks,
    }
})
