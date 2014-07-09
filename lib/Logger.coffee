{MessagePanelView, PlainMessageView} = require "atom-message-panel"


module.exports =
class Logger
  constructor: (title) ->
    @panel = new MessagePanelView title: title

  showInPanel: (message) ->
    @panel.attach()
    @panel.setSummary message
    @panel.add new PlainMessageView message: message

  log: (message) ->
    if atom.config.get("remote-sync.logToConsole")
      console.log message
    else
      @showInPanel message

  error: (message) ->
    @panel.unfold()
    @showInPanel "Error: #{message}"
