RemoteSync = require "./lib/RemoteSync"


module.exports =
  activate: (state) ->
    new RemoteSync
