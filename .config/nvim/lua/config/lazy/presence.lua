return {
    'andweeb/presence.nvim',
    lazy = false,
    config = function()
        require('presence').setup({
            neovim_image_text = '"How do I exit this stupid text editor?" - holybaechu',
        })
    end
}
