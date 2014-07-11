module.exports =
  configDefaults:
    logToConsole: false
    difftoolCommand: 'diffToolPath'

  activate: (state) ->
    if atom.project.getPath()
      doActive()
    else
      atom.project.once "path-changed", -> doActive

doActive=->
  RemoteSync = require "./lib/RemoteSync"
  RemoteSync.activate()
