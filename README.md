# NeorgUtils

> [!todo]
> 
> Add Screenshots

> [!warning]
> 
> This is a highly opinionated plugin. I built this for the sole purpose of
> streamlining my workflow. To that end, my implementation is highly
> opinionated and leaves very little room for customisation or personalisation.
> 
> They may not be the right or most optimal way to do things, but it works for
> me. So, use at your own risk.

## Installation

This works alongside your [Neorg](https://github.com/nvim-neorg/neorg) installation.

### `lazy.nvim`

```lua
return {
    "nvim-neorg/neorg",
    dependencies = {
        "juniorsundar/neorg_utils",
        "nvim-telescope/telescope.nvim", -- Required for the Neorg-Roam features
        "nvim-lua/plenary.nvim" -- Required as part of Telescope installation
    },
    config = function()
        -- ... Your configs

        -- I add this line here because I want to open 
        -- up the default Neorg workspace whenever a Neovim instance
        -- is started
        require("neorg.core").modules.get_module("core.dirman").set_workspace("default") 
    end
}
```

### Others

I don't use any other plugin managers. I haven't tested this with any others.
If anyone happens to test it with `packer`, `rocks.nvim`, etc. please feel free
to create a pull request.

## Features

### Neorg-Roam

#### Set Workspace

#### Nodes

#### Blocks

#### Backlinks

### Neorg-Agenda

#### Agenda View
