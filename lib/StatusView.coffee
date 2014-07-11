{View} = require 'atom'

module.exports =
class StatusView extends View
  @content: ->
    @a href: '#', ' SFTP'

  initialize: ->
    @on 'click', ->
      atom.workspaceView.trigger 'remote-sync:reload-config'
      false
    @attach()

  attach: =>
    statusBar = atom.workspaceView.statusBar
    if statusBar
      statusBar.appendLeft(this)
    else
      @subscribe(atom.packages.once('activated', @attach))

  update: (iconName, tips) =>
    this.element.className = "inline-block icon icon-#{iconName}"
    tips = "" if not tips
    @setTooltip(tips+" Click to reload config.")
