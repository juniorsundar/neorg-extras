<div align="center">

# NeorgExtras

Highly opinionated Neorg add-on to streamline organising your life in plain-text. 

</div>
<div align="center">
<br>
</div>

<!--toc:start-->
- [NeorgExtras](#neorgextras)
- [System Prerequisites](#system-prerequisites)
- [Installation](#installation)
  - [`lazy.nvim`](#lazynvim)
  - [Others](#others)
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
    - [Use-Case](#use-case)
    - [Function](#function)
    - [Default Mappings](#default-mappings)
  - [Backlinks](#backlinks)
    - [Rationale](#rationale)
    - [Use-Case](#use-case)
    - [Function](#function)
- [Neorg-Agenda](#neorg-agenda)
  - [Rationale](#rationale)
  - [Agenda View](#agenda-view)
    - [Page View](#page-view)
    - [Day View (TM)](#day-view-tm)
      - [The View](#the-view)
      - [The Property Metadata](#the-property-metadata)
      - [Sorting-out my Life](#sorting-out-my-life)
- [To-Do](#to-do)
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

# System Prerequisites

- ripgrep [`rg`](https://github.com/BurntSushi/ripgrep)
- fd [`fd`](https://github.com/sharkdp/fd)

# Installation

This works alongside your [Neorg](https://github.com/nvim-neorg/neorg) installation.

## `lazy.nvim`

```lua
return {
    "nvim-neorg/neorg",
    dependencies = {
        { "juniorsundar/neorg_extras", opts = {} }, -- opts will have some use later
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

## Others

I don't use any other plugin managers. I haven't tested this with any others.
If anyone happens to test it with `packer`, `rocks.nvim`, etc., please feel free
to create a pull request.

# Neorg-Roam

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

## Set Workspace

### Function

`Telescope neorg_workspace_selector`

### Default Mappings

| Mappings | Action                                                                        |
|----------|-------------------------------------------------------------------------------|
| `<CR>`   | Sets workspace.                                                               |
| `<C-i>`  | Sets workspace and opens the `index.norg` file in the workspace if it exists. |

## Nodes

### Rationale

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

### Use-Case

You want to navigate to a node in your workspace.

You want to insert the node into your cursor location as a link.

The node you want doesn't exist yet, and you want to create one with the title
currently present in the Telescope search. This will drop the new node with
unique filename into a `vault` folder in the workspace root.

> [!NOTE]
> TODO Change the vault folder default.

### Function

`Telescope neorg_node_injector`

### Default Mappings

| Mappings | Action                                                                                                                         |
|----------|--------------------------------------------------------------------------------------------------------------------------------|
| `<CR>`     | Open to selected node.                                                                                                          |
| `<C-i>`    | Inserts hovering node into cursor location. Node's title will be concealing alias. Eg: `{:$/workspace/path/tonode:}[Title]`.     |
| `<C-n>` | Creates new node with title of text in search bar and unique node name. |

## Blocks

### Rationale

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

### Use-Case

You want to navigate to a block in your workspace.

You want to insert the block into your cursor location as a link.

### Function

`Telescope neorg_block_injector`

### Default Mappings

| Mappings | Action                                                                        |
|----------|-------------------------------------------------------------------------------|
| `<CR>`   | Open to selected block.                                                                |
| `<C-i>`  | Inserts hovering block into cursor location. |

## Backlinks

### Rationale

Since we are swearing off the file-tree, we need a way to conveniently navigate between nodes. The backlinks offer us an insight into the ways we can get to the current node.

> [!IMPORTANT]
> I believe that using Telescope to list out backlinks and using that as a
> navigation methodology is flawed because you cannot have it open when working
> on a current node. Backlinks should be visible at all times to be truly
> effective, and if I have to press a keymap to open it, it wastes valuable
> time.
> 
> TODO change this into a read-only buffer that can be toggled.

### Use-Case

You want to determine all backlinks to current node, preview them, and navigate to them.

### Function

| Mappings | Action                                                                        |
|----------|-------------------------------------------------------------------------------|
| `<CR>`   | Open to selected backlink location.                                           |

# Neorg-Agenda

In order to organise your life in plain-text, you need to be able to open up
your backlog of work... right? Neorg devs have a GTD system in their pipeline,
but to create anything great you need to invest a lot of time. I am an
inherently impatient person, so I decided to build something temporary that I
can use in the meantime.

## Rationale

I don't want to deviate excessively and create new grammar to accommodate my
GTD because if, in the future, Neorg gains its own builtin GTD feature, I want
to minimise issues of backwards compatibility. The last thing I want is to go
through all my old files and remove artefacts that will interfere with the new
and definitely superior GTD implementation.

## Agenda View

A new buffer that contains all the tasks in your workspace. Note that it will
only consider tasks that are prefixed with a heading tag:

```norg
* ( ) This task is recoginsed

- ( ) This task is not ... yet
```

So if you are someone who prefers to use a bullet based task listing strategy,
this may not be the plugin for you.

### Page View

![Neorg Page View](https://i.imgur.com/Hql5Pet.png)

This will show all tasks filtered by the provided task states and turn it into a paginated view.

`NeorgExtras Page <task-states>`

You can list out all possible Neorg task states:

- `ambiguous`
- `cancelled`
- `done`
- `hold`
- `pending`
- `important`
- `recurring`
- `undone`

**Examples**

`NeorgExtras Page undone pending` <- Will open agenda view with all pending
and undone tasks in current workspace.

Tasks are currently segregated by the nodes they are found in. You can hit
`<CR>` over the node names to navigate to those nodes as they are hyperlinks.

The agenda view can be closed with `q`.

### Day View (TM)

#### The View

![Neorg Day View](https://i.imgur.com/oFZmfd0.png)

This will sort tasks according to a day view. Something similar to
`org-agenda` but with my own flavour.

`NeorgExtras Day`

You will notice that all of your tasks in the workspace are uncategorised. This
is because we haven't added the property `ranged_verbatim_tag` that is used
in this plugin-plugin (plugin^2?) to define the sorting categories for the
agenda.

Note that the method I am using to assign "metadata" to tasks is not the
official way to do things. That is still awaiting an update of the tree-sitter
parser. I don't know how long that will take. And as someone who wants to
organise their life yesterday, I can't afford to wait that long. Hence:

#### The Property Metadata

```norg
@data property
started: YYYY-MM-DD|HH:MM
completed: YYYY-MM-DD|HH:MM
deadline: YYYY-MM-DD|HH:MM
tag: tag1, tag2, ...
priority: A/B/C ...
@end
```

Fair warning, this verbose property tag will not conceal, so you are going to
have this chunk in your view. You should decide if you can live with that.
Because if you can, only then can you access the Day View (TM).

Of course, this plug(plugin)in(?) makes your life a lot easier by exposing the
following function:

`NeorgExtras Metadata update`

This function doesn't discriminate between task headings or regular headings
(at the moment... I will fix that later).

This function is multi-purpose:

1. It can add the property tag to the current heading if it doesn't have one
   already.
2. It will update the property tag under the current heading if it has one
   already.

   #### Sorting-out my Life

I would suggest that you open your Day View (TM) and start going through your
uncategorised tasks and start assigning them a started and deadline property.
Maybe add a tag? You could also add a property (but I haven't implemented
support for finer sorting yet).

# To-Do

- [ ] Deadline and time based scheduling
- [ ] Sorting by dates, tags, etc.
- [ ] A better UI...
