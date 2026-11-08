return {
  {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = false,
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("nvim-tree").setup({
        renderer = {
          -- note on icons:
          -- in some terminals, some patched fonts cut off glyphs if not given extra space
          -- either add extra space, disable icons, or change font
          icons = {
            show = {
              file = false,
              folder = false,
              folder_arrow = true,
              git = true,
            },
          },
        },
        view = {
          width = 25,
          side = "left",
        },
        sync_root_with_cwd = true, -- fix to open cwd with tree
        respect_buf_cwd = true,
        update_cwd = true,
        update_focused_file = {
          enable = true,
          update_cwd = true,
          update_root = true,
        },
      })

      vim.g.nvim_tree_respect_buf_cwd = 1

      -- Optional keymap: toggle focus between tree and file using Tab
      vim.keymap.set("n", "<Tab>", function()
        local api = require("nvim-tree.api")
        if api.tree.is_visible() then
          if vim.bo.filetype == "NvimTree" then
            vim.cmd("wincmd l") -- move right
          else
            api.tree.focus() -- focus tree
          end
        else
          vim.cmd("wincmd w") -- normal tab behavior if tree is closed
        end
      end, { desc = "Toggle focus between file and explorer" })
    end,
  },
}

