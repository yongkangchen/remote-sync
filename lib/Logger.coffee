PlainMessageView = null


module.exports =
class Logger
  constructor: (@title) ->

  showInPanel: (message, toggle) ->
    if not @panel
      {MessagePanelView, PlainMessageView} = require "atom-message-panel"
      @panel = new MessagePanelView title: title

    @panel.unfold() if toggle

    @panel.attach()
    @panel.setSummary message
    @panel.add new PlainMessageView message: message

  log: (message) ->
    if atom.config.get("remote-sync.logToConsole")
      console.log message
    else
      @showInPanel message

  error: (message) ->
    @showInPanel "Error: #{message}", true
