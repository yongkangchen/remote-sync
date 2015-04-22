{View} = require 'atom'

module.exports =
class StatusView extends View
  @content: ->
    @a ' Sync'

  @attached = false

  initialize: ->
    @on 'click', ->
      atom.commands.dispatch atom.views.getView(atom.workspace), 'remote-sync:configure'
      false
    if atom.config.get("remote-sync.alwaysShowInStatusBar")
      @attach()

  attach: =>
    statusBar = atom.views.getView(atom.workspace).querySelector('.status-bar')
    if statusBar
      statusBar.addLeftTile item: this
      @attached = true
    else
      @subscribe(atom.packages.once('activated', @attach))

  update: (iconName, tips, text) =>
    if @attached
      @element.className = "inline-block icon icon-#{iconName}" if iconName
      @setTooltip(if tips then tips + " Click to configure." else "Click to configure.")
      @text(if text then " Sync: " + text else " Sync")
