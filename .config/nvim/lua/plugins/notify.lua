-- notification pop-ups
-- https://github.com/rcarriga/nvim-notify

return {
  'rcarriga/nvim-notify',
  event = 'VeryLazy',
  config = function()
    local notify = require('notify')

    notify.setup({
    })
  end,
}
