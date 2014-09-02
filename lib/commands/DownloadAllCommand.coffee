minimatch = null
async = null


module.exports =
  run:(logger, transport, path, targetPath, callback) ->
    minimatch = require "minimatch" if not minimatch
    async = require "async" if not async

    logger.log "Downloading all files: #{path}"

    transport.fetchFileTree path, (err, files) ->
      return logger.error err if err

      async.mapSeries files, (file, callback) ->
        transport.download file, targetPath, callback
      , (err) ->
        return logger.error if err
        return logger.error err if err
        logger.log "Downloaded all files: #{path}"
        callback?()
