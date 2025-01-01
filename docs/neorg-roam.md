# Set Workspace

## Function

`Neorg roam select_workspace`

## Default Mappings

| Mappings | Action                                                                        |
|----------|-------------------------------------------------------------------------------|
| `<CR>`   | Sets workspace.                                                               |
| `<C-i>`  | Sets workspace and opens the `index.norg` file in the workspace if it exists. |

# Nodes

## Rationale

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

## Use-Case

You want to navigate to a node in your workspace.

You want to insert the node into your cursor location as a link.

The node you want doesn't exist yet, and you want to create one with the title
currently present in the Telescope search. This will drop the new node with
unique filename into a `roam_base_directory` folder in the workspace root.

## Function

`Neorg roam node`

## Default Mappings

| Mappings | Action |
|----------|-------------------------------------------------------------------------------------------------------------------------------|
| `<CR>` | Open to selected node.|
| `<C-i>`| Inserts hovering node into cursor location. Node's title will be concealing alias. Eg: `{:$/workspace/path/tonode:}[Title]`.|
| `<C-n>` | Creates new node with title of text in search bar and unique node name. |

# Blocks

## Rationale

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

## Use-Case

You want to navigate to a block in your workspace.

You want to insert the block into your cursor location as a link.

## Function

`Neorg roam block`

## Default Mappings

| Mappings | Action                                       |
|----------|----------------------------------------------|
| `<CR>`   | Open to selected block.|
| `<C-i>`  | Inserts hovering block into cursor location. |

# Backlinks

## Rationale

Since we are swearing off the file-tree, we need a way to conveniently navigate
between nodes. The backlinks offer us an insight into the ways we can get to
the current node.

There are two options to view backlinks. Depending on whether to the
configuration `fuzzy_backlinks` is set to `false` or `true`:
- `false` - (default) Opens the backlinks as a vertical-split buffer.
- `true` - Opens the backlinks within the selected fuzzy-finder.

As a buffer, the entries are **folded**. You can unfold then to reveal a
preview from where the backlinks are extracted. This isn't necessary with the
fuzzy-finder as it can be configured to show an automatic preview.

## Use-Case

You want to determine all backlinks to current node, preview them, and navigate to them.

## Function

`Neorg roam backlinks`

## Default Mappings

| Mappings | Action                                                                        |
|----------|-------------------------------------------------------------------------------|
| `<CR>`   | Open to selected backlink location.                                           |

# Capture

## Rationale

Its common to forgot things. Just so you don't, why not capture it?

Capturing shouldn't be difficult, it should be accessible from anywhere. And
getting the captured information shouldn't be difficult either.

## Use-Case

There are two primary types of use-cases:
1. Capturing idea/task/content
2. Capturing annotation

**In case (1)**
You are working and suddenly remember a task you need to accomplish. Simply
call `Neorg roam capture todo`. This will open a temporary buffer where you
can capture the task. Once closed, it will append this content into your daily
journal for the day.

**In case (2)**
There's a really cool code snippet that you want to use at a later time. Simply
select the range in "visual" mode and call `'<,'>Neorg roam capture selection`. 
Annotate as you wish and close the buffer. It will be appended into your daily
journal for the day.

## Function

`Neorg roam capture <anything>`

> [!NOTE]
> The following functions are templated. The templates are generated in
> "<WORKSPACE_ROOT>/.capture-templates".
> 
> `Neorg roam capture todo`  
> `Neorg roam capture note`  
> `Neorg roam capture meeting`  
> `Neorg roam capture selection`  
> 
> You can add more templates into this directory.

## Default Mappings

In the capture buffer.

| Mappings     | Action                                   |
|--------------|------------------------------------------|
| `<C-c><C-c>` | Commit captured content to daily journal.|
| `q`          | Close capture buffer and delete content. |

