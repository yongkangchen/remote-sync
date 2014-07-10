
minimatch = null
async = null

module.exports =
class UploadListener

  constructor: (@logger, @settingsLocator, @transports) ->

  handleSave: (buffer) ->
    @settingsLocator.locate buffer.file.path, (err, result) =>
      return @logger.error err if err
      return if not result
      if not @queue
        async = require "async" if not async
        @queue = async.queue(@uploadFile.bind(@), 1)

      @queue.push
        settingsFilePath: result.settingsFilePath
        rootDirectory: result.rootDirectory
        relativeFilePath: result.relativeFilePath
        settings: result.settings

  uploadFile: (task, callback) ->
    {rootDirectory, relativeFilePath, settings} = task

    if settings.ignore
      minimatch = require "minimatch" if not minimatch
      settings.ignore = [settings.ignore] unless Array.isArray settings.ignore
      for pattern in settings.ignore
        if minimatch relativeFilePath, pattern
          return callback()

    transport = @transports[settings.transport.toLowerCase()]

    unless transport
      @logger.error "Unkown transport \"#{settings.transport}\" defined in \"#{task.settingsFilePath}\""
      return callback()

    transport.upload rootDirectory, relativeFilePath, settings, callback
