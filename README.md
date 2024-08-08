# NeorgUtils

> [!warning] Use with Caution
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
        config = function()

        end,
    },
    config = true,
}
```
