module.exports =
  config:
    logToConsole:
      type: 'boolean'
      default: false
      title: 'Log to console'
      description: 'Log messages to the console instead of the status view at the bottom of the window'
    difftoolCommand:
      type: 'string'
      default: ''
      title: 'Diff tool command'
      description: 'The command to run for your diff tool'

  activate: (state) ->
    doActive()

doActive=->
  if atom.project.getPath()
    RemoteSync = require "./lib/RemoteSync"
    RemoteSync.activate()
  else
    atom.project.once "path-changed", doActive
