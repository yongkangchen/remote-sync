minimatch = null
async = null


module.exports =
class DownloadAllCommand
  constructor: (@logger, @settingsLocator, @transports) ->

  run: ->
    minimatch = require "minimatch" if not minimatch
    async = require "async" if not async

    buffer = atom.workspace.getActiveEditor().getBuffer()
    return unless buffer.file
    filePath = buffer.file.path
    @settingsLocator.locate filePath, (err, result) =>
      return @logger.error err if err

      settings = result.settings

      @transports[settings.transport].fetchFileTree settings, (err, files) =>
        return @logger.error err if err

        if settings.ignore
          patterns = settings.ignore
          files = files.filter (file) ->
            for pattern in patterns
              if minimatch file, pattern
                return false
            return true

        async.mapSeries files, (file, callback) =>
          @transports[settings.transport].download result.rootDirectory, file, settings, callback
        , (err) =>
          return @logger.error if err
          return @logger.error err if err
          @logger.log "Downloaded all files"
