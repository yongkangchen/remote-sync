PlainMessageView = null


module.exports =
class Logger
  constructor: (@title) ->

  showInPanel: (message, className) ->
    if not @panel
      {MessagePanelView, PlainMessageView} = require "atom-message-panel"
      @panel = new MessagePanelView
        title: @title

    @panel.attach()
    @panel.add new PlainMessageView
      message: message
      className: className

    @panel.setSummary
      summary: message
      className: className

  log: (message) ->
    if atom.config.get("remote-sync.logToConsole")
      console.log message
    else
      @showInPanel message,"text-info"

  error: (message) ->
    @showInPanel "#{message}","text-error"
