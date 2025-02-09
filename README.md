<div align="center">

<img src="https://i.imgur.com/20X5DNx.png" width=300>

# [Neorg](https://github.com/nvim-neorg/neorg)Extras

Highly opinionated Neorg add-on to streamline organising your life in plain-text. 

</div>
<div align="center">
<br>
</div>

> [!warning]
> 
> This is a highly opinionated plugin. I built this for the sole purpose of
> streamlining my workflow. To that end, my implementation is highly
> opinionated and leaves very little room for customisation or personalisation.
> 
> They may not be the right or most optimal way to do things, but it works for
> me. So, use at your own risk.

# System Prerequisites

- ripgrep [`rg`](https://github.com/BurntSushi/ripgrep)
- fd [`fd`](https://github.com/sharkdp/fd)

# Installation

This works alongside your [Neorg](https://github.com/andreadev-it/neorg-module-tutorials/blob/main/introduction.md#adding-it-to-neorg) installation.

## `lazy.nvim`

```lua
return {
    "nvim-neorg/neorg",
    dependencies = {
        {
            "juniorsundar/neorg-extras",
            -- tag = "*" -- Always a safe bet to track current latest release
        },
        -- FOR Neorg-Roam Features
        --- OPTION 1: Telescope
        "nvim-telescope/telescope.nvim",
        "nvim-lua/plenary.nvim",
        -- OR OPTION 2: Fzf-Lua
        "ibhagwan/fzf-lua",
        -- OR OPTION 3: Snacks
        "folke/snacks.nvim"
    },
    config = function()
        require('neorg').setup({
            load = {
                -- MANDATORY
                ["external.many-mans"] = {
                    config = {
                        metadata_fold = true, -- If want @data property ... @end to fold
                        code_fold = true, -- If want @code ... @end to fold
                    }
                },
                -- OPTIONAL
                ["external.agenda"] = {
                    config = {
                        workspace = nil, -- or set to "tasks_workspace" to limit agenda search to just that workspace
                    }
                },
                ["external.roam"] = {
                    config = {
                        fuzzy_finder = "Telescope", -- OR "Fzf" OR "Snacks". Defaults to "Telescope"
                        fuzzy_backlinks = false, -- Set to "true" for backlinks in fuzzy finder instead of buffer
                        roam_base_directory = "", -- Directory in current workspace to store roam nodes
                        node_name_randomiser = false, -- Tokenise node name suffix for more randomisation
                        node_name_snake_case = false, -- snake_case the names if node_name_randomiser = false
                    }
                },
            }
        })

        -- I add this line here because I want to open 
        -- up the default Neorg workspace whenever a Neovim instance
        -- is started
        require("neorg.core").modules.get_module("core.dirman").set_workspace("default") 
    end
}
```

## Others

I don't use any other plugin managers. I haven't tested this with any others.
If anyone happens to test it with `packer`, `rocks.nvim`, etc., please feel free
to create a pull request.

# [Neorg-Roam](./docs/neorg-roam.md)

At the moment, this feature relies heavily on the a 3rd-Party Fuzzy Finder ([Telescope](https://github.com/nvim-telescope/telescope.nvim) or [Fzf-Lua](https://github.com/ibhagwan/fzf-lua)).
I have plans to liberate this plugin from this need, but that
is something way down in the future after I have implemented the required basic
features. So, for the moment, users of this plugin will have to bear with this
dependency.

Also note that there are a lot of similarities in this plugin with [`nvim-neorg/neorg-telescope`](https://github.com/nvim-neorg/neorg-telescope).
It implements these features much better than I do, and more cleanly that I do.
If you are comfortable using that, then you can install it along side this
plugin and simply skip the Neorg-Roam feature-set.

# [Neorg-Agenda](./docs/neorg-agenda.md)

In order to organise your life in plain-text, you need to be able to open up
your backlog of work... right? Neorg devs have a GTD system in their pipeline,
but to create anything great you need to invest a lot of time. I am an
inherently impatient person, so I decided to build something temporary that I
can use in the meantime.

## Rationale

I don't want to deviate excessively and create new grammar to accommodate my
GTD because if, in the future, Neorg gains its own builtin GTD feature, I want
to minimise issues of backwards compatibility. The last thing I want is to go
through all my old files and remove artifacts that will interfere with the new
and definitely superior GTD implementation.

## Views

A new buffer that contains all the tasks in your workspace. Note that it will
only consider tasks that are prefixed with a heading tag:

```norg
* ( ) This task is recoginsed

- ( ) This task is not ... yet
```

So if you are someone who prefers to use a bullet based task listing strategy,
this may not be the plugin for you.

# To-Do

## Primary

- [x] Deadline and time based scheduling
- [x] Sorting by dates, tags, etc.
    - [x] Sorting by date and priority (default)
    - [x] Sorting by tags
- [ ] Better UI for property tag population (especially dates and times)
- [x] Wrapper around task changer to auto-generate property metadata
- [ ] Alternate views (open to discussion)
- [ ] Permalinking for Neorg-Roam
- [x] Better UI for Backlinks (Telescope/Fuzzy finder is too distracting)

## Secondary

- [ ] Generating graphs for organising tasks
- [ ] Kanban?
