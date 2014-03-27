SettingsLocator = require "./SettingsLocator"
UploadListener = require "./UploadListener"
ScpTransport = require "./transports/ScpTransport"
Logger = require "./Logger"


module.exports =
class RemoteSync
  constructor: ->
    logger = new Logger "Remote Sync"

    settingsLocator = new SettingsLocator

    transports =
      scp: new ScpTransport logger

    new UploadListener logger, settingsLocator, transports
