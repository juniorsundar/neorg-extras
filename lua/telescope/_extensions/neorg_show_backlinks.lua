local telescopic = require("neorg-extras.telescopic")

return require("telescope").register_extension({
    exports = {
        neorg_show_backlinks = telescopic.show_backlinks,
    }
})
