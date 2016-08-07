PlainMessageView = null
AutoHideTimer = null

module.exports =
class Logger
  constructor: (@title) ->

  showInPanel: (message, className) ->
    if not @panel
      {MessagePanelView, PlainMessageView} = require "atom-message-panel"
      @panel = new MessagePanelView
        title: @title

    @panel.attach()
    msg = new PlainMessageView
      message: message
      className: className

    @panel.add msg

    @panel.setSummary
      summary: message
      className: className

    @panel.body.scrollTop(1e10)

    if atom.config.get("remote-sync.foldLogPanel") and not @foldedPanel
      @panel.toggle()
      @foldedPanel = true

    msg

  log: (message) ->
    date = new Date
    startTime = date.getTime()
    message = "[#{date.toLocaleTimeString()}] #{message}"
    if atom.config.get("remote-sync.logToConsole")
      console.log message
      ()->
        console.log "#{message} Complete (#{Date.now() - startTime}ms)"
    else
      if AutoHideTimer
        clearTimeout AutoHideTimer
        AutoHideTimer = null
      msg = @showInPanel message, "text-info"
      ()=>
          endMsg = " Complete (#{Date.now() - startTime}ms)"
          msg.append endMsg
          @panel.setSummary
            summary: "#{message} #{endMsg}"
            className: "text-info"
          if atom.config.get("remote-sync.autoHideLogPanel")
            AutoHideTimer = setTimeout @panel.close.bind(@panel), 1000

  error: (message) ->
    @showInPanel "#{message}","text-error"
