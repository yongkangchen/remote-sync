{View} = require 'atom'

module.exports =
class StatusView extends View
  @content: ->
    @a ' Sync'

  initialize: ->
    @on 'click', ->
      atom.commands.dispatch atom.views.getView(atom.workspace), 'remote-sync:configure'
      false
    @attach()

  attach: =>
    statusBar = atom.views.getView(atom.workspace).querySelector('.status-bar')
    if statusBar
      statusBar.addLeftTile item: this
    else
      @subscribe(atom.packages.once('activated', @attach))

  update: (iconName, tips, text) =>
    @element.className = "inline-block icon icon-#{iconName}" if iconName
    @setTooltip(if tips then tips + " Click to reload config." else "Click to reload config.")
    @text(if text then " Sync: " + text else " Sync")
