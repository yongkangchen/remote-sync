
download = null
upload = null

loaded = false

logger = null
settingsLocator = null
transports = null

module.exports =
  configDefaults:
    logToConsole: false

  activate: ->
    atom.workspace.eachEditor (editor) ->
      handleEvents(editor)

    atom.workspaceView.command "remote-sync:download-all", ->
      if not download
        checkModule()
        DownloadAllCommand = require "./commands/DownloadAllCommand"
        download = new DownloadAllCommand logger, settingsLocator, transports
      download.run()

handleEvents = (editor) ->
  buffer = editor.getBuffer()
  bufferSavedSubscription = buffer.on 'saved', ->
    if not upload
      checkModule()
      UploadListener = require "./UploadListener"
      upload = new UploadListener logger, settingsLocator, transports

    upload.handleSave(buffer)

  buffer.on "destroyed", =>
    bufferSavedSubscription.off()

checkModule = ->
  return if loaded
  loaded = true

  Logger = require "./Logger"
  SettingsLocator = require "./SettingsLocator"
  ScpTransport = require "./transports/ScpTransport"

  settingsLocator = new SettingsLocator
  logger = new Logger "Remote Sync"

  transports =
    scp: new ScpTransport logger
