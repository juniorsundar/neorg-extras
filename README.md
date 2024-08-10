# NeorgUtils

<!--toc:start-->
- [NeorgUtils](#neorgutils)
  - [Installation](#installation)
    - [`lazy.nvim`](#lazynvim)
    - [Others](#others)
  - [Features](#features)
    - [Neorg-Roam](#neorg-roam)
      - [Set Workspace](#set-workspace)
        - [Function](#function)
        - [Default Mappings](#default-mappings)
      - [Nodes](#nodes)
        - [Rationale](#rationale)
          - [Use-Case](#use-case)
        - [Function](#function)
        - [Default Mappings](#default-mappings)
      - [Blocks](#blocks)
        - [Rationale](#rationale)
      - [Backlinks](#backlinks)
    - [Neorg-Agenda](#neorg-agenda)
      - [Agenda View](#agenda-view)
<!--toc:end-->

> [!NOTE]
> 
> TODO Add Screenshots

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
        { "juniorsundar/neorg_utils", opts = {} }, -- opts will have some use later
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
If anyone happens to test it with `packer`, `rocks.nvim`, etc., please feel free
to create a pull request.

## Features

### Neorg-Roam

At the moment, this feature relies heavily on the [`telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim) plugin.
I have plans to liberate this plugin from the need of using Telescope, but that
is something way down in the future after I have implemented the required basic
features. So, for the moment, users of this plugin will have to bear with this
dependency.

Also note that there are a lot of similarities in this plugin with [`nvim-neorg/neorg-telescope`](https://github.com/nvim-telescope/telescope.nvim).
It implements these features much better than I do, and more cleanly that I do.
If you are comfortable using that, then you can install it along side this
plugin and simply skip the Neorg-Roam feature-set.

> [!NOTE]
>
> TODO In the future. I will implement a flag that will turn this off (maybe...
> IDK).

#### Set Workspace

##### Function

`Telescope neorg_workspace_selector`

##### Default Mappings

| Mappings | Action                                                                        |
|----------|-------------------------------------------------------------------------------|
| `<CR>`   | Sets workspace                                                                |
| `<C-i>`  | Sets workspace and opens the `index.norg` file in the workspace if it exists. |

#### Nodes

##### Rationale

Nodes are defined as the individual pages within a workspace. The node name is
defined as the `title` in the page metadata. The node filename is irrelevant
and should only be unique.

True to the `org-roam` or `logseq` mindset. You shouldn't have to worry
about organising your workspace files, because you won't be navigating your
file-tree to find them. Relations should be made using linking rather than
sorting.

**Example** If you want to sort your nodes according to projects. Create one
(1) node with the "Projects" title and other nodes with titles corresponding to
your project names and include their links in the "Projects" node. You can go
to your projects by either directly opening that node from your fuzzy finder or
opening "Projects" and opening the corresponding project node from the inserted
link.

You need to agree to this philosophy of managing your work to take full
advantage of this feature.

###### Use-Case

You want to navigate to a node in your workspace.

You want to insert the node into your cursor location as a link.

The node you want doesn't exist yet, and you want to create one with the title
currently present in the Telescope search. This will drop the new node with
unique filename into a `vault` folder in the workspace root.

> [!NOTE]
> TODO Change the vault folder default.

##### Function

`Telescope neorg_node_injector`

##### Default Mappings

| Mappings | Action                                                                                                                         |
|----------|--------------------------------------------------------------------------------------------------------------------------------|
| `<CR>`     | Open to selected node                                                                                                          |
| `<C-i>`    | Inserts hovering node into cursor location. Node's title will be concealing alias. Eg: `{:$/workspace/path/tonode:}[Title]`.     |
| `<C-n>` | Creates new node with title of text in search bar and unique node name. |

#### Blocks

##### Rationale

Blocks are defined as the headings within a workspace. The block name is
defined as the heading text.

In `logseq`, the block is considered a first-class citizen. In `org-roam` it
could be, as long as you assign a unique ID property to said block. The benefit
of this is that even if the block is changed, any hyperlink to the block will
be unaffected.

This isn't a particular feature like that in Neorg as of yet. There may be
something like this in the future.

> [!NOTE]
> TODO find ways to treat blocks as first-class citizens.

##### Use-Case

You want to navigate to a block in your workspace.

You want to insert the block into your cursor location as a link.

##### Function

`Telescope neorg_block_injector`

##### Default Mappings

| Mappings | Action                                                                        |
|----------|-------------------------------------------------------------------------------|
| `<CR>`   | Open to selected block                                                                |
| `<C-i>`  | Inserts hovering block into cursor location. |

#### Backlinks

##### Rationale

##### Use-Case

##### Function

### Neorg-Agenda

#### Agenda View
