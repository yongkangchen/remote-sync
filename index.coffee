module.exports =
  configDefaults:
    logToConsole: false
    difftoolCommand: 'diffToolPath'

  activate: (state) ->
    doActive()

doActive=->
  if atom.project.getPath()
    RemoteSync = require "./lib/RemoteSync"
    RemoteSync.activate()
  else
    atom.project.once "path-changed", doActive
