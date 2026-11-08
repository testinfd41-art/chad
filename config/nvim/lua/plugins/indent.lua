return {
  "lukas-reineke/indent-blankline.nvim",
  main = "ibl",
  opts = {
    indent = {
      char = "│",
      tab_char = "│",
    },
    scope = { enabled = true },
  },
  config = function(_, opts)
    require("ibl").setup(opts)
  end,
}

