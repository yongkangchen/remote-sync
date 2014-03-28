minimatch = require "minimatch"
async = require "async"


module.exports =
class DownloadAllCommand
  constructor: (@logger, @settingsLocator, @transports) ->

  run: ->
    buffer = atom.workspace.getActiveEditor().getBuffer()
    return unless buffer.file
    filePath = buffer.file.path
    @settingsLocator.locate filePath, (err, result) =>
      return if err

      settings = result.settings

      @transports[settings.transport].fetchFileTree settings, (err, files) =>
        return if err

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
          @logger.log "Downloaded all files"
