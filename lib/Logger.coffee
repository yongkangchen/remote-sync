{MessagePanelView, PlainMessageView} = require "atom-message-panel"


module.exports =
class Logger
  constructor: (title) ->
    @panel = new MessagePanelView title: title

  log: (message) ->
    @panel.attach()
    @panel.setSummary message
    @panel.add new PlainMessageView message: message

  error: (message) ->
    @panel.unfold()
    @log "Error: #{message}"
