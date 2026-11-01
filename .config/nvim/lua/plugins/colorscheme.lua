return {
    -- {
    --     "folke/tokyonight.nvim",
    --     opts = {
    --         -- transparent = true,
    --         styles = {
    --             sidebars = "transparent",
    --             floats = "transparent",
    --         },
    --     },
    -- },

    -- colours from the wallpaper: matugen renders ~/.cache/matugen/nvim.json, the plugin watches it
    {
        "daedlock/matugen.nvim",
        lazy = false,
        priority = 1000,
        opts = {
            colors_path = "~/.cache/matugen/nvim.json",
        },
    },

    -- LazyVim applies this colorscheme (default would be tokyonight)
    {
        "LazyVim/LazyVim",
        opts = { colorscheme = "matugen" },
    },
}
