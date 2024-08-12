local telescopic = require("neorg-extras.telescopic")

return require("telescope").register_extension({
    exports = {
        neorg_workspace_selector = telescopic.neorg_workspace_selector,
    }
})

