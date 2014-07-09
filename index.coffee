RemoteSync = require "./lib/RemoteSync"


module.exports =
  configDefaults:
    logToConsole: false
    
  activate: (state) ->
    new RemoteSync
