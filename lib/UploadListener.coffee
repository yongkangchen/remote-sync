{MessagePanelView, PlainMessageView} = require "atom-message-panel"
{Subscriber} = require "emissary"
minimatch = require "minimatch"
async = require "async"
path = require "path"
fs = require "fs"


SETTINGS_FILE_NAME = ".remote-sync.json"


module.exports =
class UploadListener
  Subscriber.includeInto @

  constructor: (@logger, @settingsLocator, @transports) ->
    @queue = async.queue(@uploadFile.bind(@), 1)

    @subscribe atom.workspace.eachEditor (editor) =>
      buffer = editor.getBuffer()

      bufferSavedSubscription = @subscribe buffer, "saved", =>
        @handleSave(buffer)

      @subscribe editor, "destroyed", ->
        bufferSavedSubscription.off()

      @subscribe buffer, "destroyed", =>
        @unsubscribe(buffer)

  handleSave: (buffer) ->
    @settingsLocator.locate buffer.file.path, (err, result) =>
      return @logger.error err if err

      if result
        @queue.push
          settingsFilePath: result.settingsFilePath
          rootDirectory: result.rootDirectory
          relativeFilePath: result.relativeFilePath
          settings: result.settings

  uploadFile: (task, callback) ->
    {rootDirectory, relativeFilePath, settings} = task

    if settings.ignore
      settings.ignore = [settings.ignore] unless Array.isArray settings.ignore
      for pattern in settings.ignore
        if minimatch relativeFilePath, pattern
          return callback()

    transport = @transports[settings.transport.toLowerCase()]

    unless transport
      @logger.error "Unkown transport \"#{settings.transport}\" defined in \"#{task.settingsFilePath}\""
      return callback()

    transport.upload rootDirectory, relativeFilePath, settings, callback
