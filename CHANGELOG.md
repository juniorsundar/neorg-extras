# Changelog

## [0.7.0](https://github.com/juniorsundar/neorg-extras/compare/v0.6.0...v0.7.0) (2025-02-09)


### Features

* **agenda:** Add `workspace` option for neorg-agenda ([#53](https://github.com/juniorsundar/neorg-extras/issues/53)) ([19102d0](https://github.com/juniorsundar/neorg-extras/commit/19102d07b067cca7b92dd37aad0be3adf23f4b30))
* **node:** Autogen names can be snake_cased (default: false) ([#51](https://github.com/juniorsundar/neorg-extras/issues/51)) ([ec20393](https://github.com/juniorsundar/neorg-extras/commit/ec20393536bdda5bc7e834f28a401c08c51c1cad))
* **roam:** Support for `snacks.picker` in Roam ([#54](https://github.com/juniorsundar/neorg-extras/issues/54)) ([d2ae729](https://github.com/juniorsundar/neorg-extras/commit/d2ae7290159e7bdfcb5aab483d3f59b242e7e914))


### Bug Fixes

* **fzf-lua:** Opening blocks+backlinks hang prompt ([868da79](https://github.com/juniorsundar/neorg-extras/commit/868da79e6e1e3ab9e3a7e6175cbc4713ec06359d))


### Miscellaneous Chores

* release 0.6.1 ([1bbb56b](https://github.com/juniorsundar/neorg-extras/commit/1bbb56bc8dbba73288e93106581fb93784d1c293))
* release 0.7.0 ([3a56160](https://github.com/juniorsundar/neorg-extras/commit/3a56160375c6c87de7201684df06d6a5769e7fc7))

## [0.7.0](https://github.com/juniorsundar/neorg-extras/compare/v0.6.0...v0.7.0) (2025-02-09)


### Features

* **agenda:** Add `workspace` option for neorg-agenda ([#53](https://github.com/juniorsundar/neorg-extras/issues/53)) ([19102d0](https://github.com/juniorsundar/neorg-extras/commit/19102d07b067cca7b92dd37aad0be3adf23f4b30))
* **node:** Autogen names can be snake_cased (default: false) ([#51](https://github.com/juniorsundar/neorg-extras/issues/51)) ([ec20393](https://github.com/juniorsundar/neorg-extras/commit/ec20393536bdda5bc7e834f28a401c08c51c1cad))
* **roam:** Support for `snacks.picker` in Roam ([#54](https://github.com/juniorsundar/neorg-extras/issues/54)) ([d2ae729](https://github.com/juniorsundar/neorg-extras/commit/d2ae7290159e7bdfcb5aab483d3f59b242e7e914))


### Bug Fixes

* **fzf-lua:** Opening blocks+backlinks hang prompt ([868da79](https://github.com/juniorsundar/neorg-extras/commit/868da79e6e1e3ab9e3a7e6175cbc4713ec06359d))


### Miscellaneous Chores

* release 0.6.1 ([1bbb56b](https://github.com/juniorsundar/neorg-extras/commit/1bbb56bc8dbba73288e93106581fb93784d1c293))
* release 0.7.0 ([3a56160](https://github.com/juniorsundar/neorg-extras/commit/3a56160375c6c87de7201684df06d6a5769e7fc7))

## [0.6.0](https://github.com/juniorsundar/neorg-extras/compare/v0.5.1...v0.6.0) (2025-01-01)


### Features

* **capture:** Capture notes and tasks ([#47](https://github.com/juniorsundar/neorg-extras/issues/47)) ([1adeefb](https://github.com/juniorsundar/neorg-extras/commit/1adeefb001f497d4829839180ed524c9da645e4a))
* **roam:** Can set `roam_base_directory` instead of default `vault` ([8da3083](https://github.com/juniorsundar/neorg-extras/commit/8da30833b9d535580a1cc71198e05c4db34f5821))


### Bug Fixes

* **buff-man:** Properly deleting new tab with task view ([9bc1511](https://github.com/juniorsundar/neorg-extras/commit/9bc1511c3b3e77cfb88dabaa5b07857b372d1bad))
* **documentation:** Removing some old commands ([1ac654a](https://github.com/juniorsundar/neorg-extras/commit/1ac654aa82d8219430acaf7fd33d3a35b67f8c67))
* **fzf-lua:** `&lt;C-n&gt;` wasn't properly closing fzf prompt ([#50](https://github.com/juniorsundar/neorg-extras/issues/50)) ([88f27d6](https://github.com/juniorsundar/neorg-extras/commit/88f27d6ca7bb866665e9b2104abdb7fb1e138742))
* **fzf-lua:** `&lt;CR&gt;` didn't clear fzf-lua prompt ([02e5261](https://github.com/juniorsundar/neorg-extras/commit/02e52619b5728130f377fdd4d43bb44508e57322))
* **fzf-lua:** Interruption when selecting workspace ([d1d9618](https://github.com/juniorsundar/neorg-extras/commit/d1d9618115cd6775d76770db6610db7b942e3c95))
* **fzf-lua:** workspace-selector wasn't closing promt ([141c0e9](https://github.com/juniorsundar/neorg-extras/commit/141c0e92b9d74b6c83da199a00aa78ba33fce9c0))
* **roam_base_directory:** Edge case when ~= "" ([ab6d590](https://github.com/juniorsundar/neorg-extras/commit/ab6d5906bbc88ca49430294d8acd66a69e14ac59))
* Spaces in files/folder/node names effects search ([e262d81](https://github.com/juniorsundar/neorg-extras/commit/e262d81ddb4a40cbf735243efec8635befe28406))
* **week-number:** Was one less than it was supposed to ([512462e](https://github.com/juniorsundar/neorg-extras/commit/512462ed8721ecc111d8cb23d9d49e3b6617f23c))

## [0.5.1](https://github.com/juniorsundar/neorg-extras/compare/v0.5.0...v0.5.1) (2024-11-07)


### Bug Fixes

* **agenda-views:** Populate current buffer and window first ([5e49efd](https://github.com/juniorsundar/neorg-extras/commit/5e49efde21def688ce7b0a60dd68698f0865bc18))
* **backlinks:** Escaping lines that start with @ in backlinks block ([#46](https://github.com/juniorsundar/neorg-extras/issues/46)) ([ab20194](https://github.com/juniorsundar/neorg-extras/commit/ab20194ec7618ecd151445a95e5f7e0803032a8c))
* **backlinks:** Issue with window ID resolved ([2d06525](https://github.com/juniorsundar/neorg-extras/commit/2d06525234f081dd83db44c6762e83599e1dadbd))
* **buff-man:** Clean agenda view window upon quit ([2bc8edf](https://github.com/juniorsundar/neorg-extras/commit/2bc8edf33c759279515352a0fd1475a194c784fa))
* **cycle_task:** Save on task cycle to account for buffer change ([b9132d3](https://github.com/juniorsundar/neorg-extras/commit/b9132d3f9c8d0fb65c8bb609be34634339efedab))
* Documentation to load configs ([49b6c91](https://github.com/juniorsundar/neorg-extras/commit/49b6c9142fe82aebff22f1708369d63d93b0fcbe))
* **property_metadata:** Exec auto-indent command on specified buffer ([2bd28ad](https://github.com/juniorsundar/neorg-extras/commit/2bd28ad24ec2bf572b3866c2394061af52eff149))
* **workspace-selector:** `&lt;C-i&gt;` opens the index properly ([0f429e2](https://github.com/juniorsundar/neorg-extras/commit/0f429e26ba86cd788af517f5e57ae16fb379e35f))

## [0.5.0](https://github.com/juniorsundar/neorg-extras/compare/v0.4.0...v0.5.0) (2024-10-16)


### ⚠ BREAKING CHANGES

* **treesitter_fold:** Added folding for code blocks
* **backlinks:** Better backlinks buffer ([#39](https://github.com/juniorsundar/neorg-extras/issues/39))

### Features

* **backlinks:** Better backlinks buffer ([#39](https://github.com/juniorsundar/neorg-extras/issues/39)) ([d93fa7d](https://github.com/juniorsundar/neorg-extras/commit/d93fa7df3373d2048269557668d2610563f7a8e4))
* **treesitter_fold:** Added folding for code blocks ([d93fa7d](https://github.com/juniorsundar/neorg-extras/commit/d93fa7df3373d2048269557668d2610563f7a8e4))


### Bug Fixes

* **workspace_selector:** Wasn't setting workspace with Fzf-Lua ([f7a45ef](https://github.com/juniorsundar/neorg-extras/commit/f7a45ef0b5fc833516921bcbaea65e11d80ba22d))


### Miscellaneous Chores

* release 0.5.0 ([0d44a16](https://github.com/juniorsundar/neorg-extras/commit/0d44a161f1d8053ceebb4e4d952f988194ea50f2))

## [0.4.1](https://github.com/juniorsundar/neorg-extras/compare/v0.4.0...v0.4.1) (2024-10-16)


### Bug Fixes

* **workspace_selector:** Wasn't setting workspace with Fzf-Lua ([f7a45ef](https://github.com/juniorsundar/neorg-extras/commit/f7a45ef0b5fc833516921bcbaea65e11d80ba22d))
