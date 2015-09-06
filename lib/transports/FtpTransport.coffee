FTPConnection = null
mkdirp = null
fs = null
path = require "path"

module.exports =
class FtpTransport
  constructor: (@logger, @settings, @projectPath) ->

  dispose: ->
    if @connection
      @connection.raw.quit (err, data) =>
        @logger.error err if err
      @connection = null

  delete: (localFilePath, callback) ->
    targetFilePath = path.join(@settings.target,
                                path.relative(@projectPath, localFilePath))
                                .replace(/\\/g, "/")

    errorHandler = (err) =>
      @logger.error err
      callback()

    @_getConnection (err, c) =>
      return errorHandler err if err

      end = @logger.log "Remote delete: #{targetFilePath} ..."

      c.delete targetFilePath, (err) ->
        return errorHandler err if err

        end()

        callback()

  upload: (localFilePath, callback) ->
    targetFilePath = path.join(@settings.target,
                                path.relative(@projectPath, localFilePath))
                                .replace(/\\/g, "/")

    errorHandler = (err) =>
      @logger.error err
      callback()

    @_getConnection (err, c) =>
      return errorHandler err if err

      end = @logger.log "Upload: #{localFilePath} to #{targetFilePath} ..."

      c.mkdir path.dirname(targetFilePath), true, (err) ->
        return errorHandler err if err

        c.put localFilePath, targetFilePath, (err) ->
          return errorHandler err if err

          end()

          callback()

  download: (targetFilePath, localFilePath, callback) ->
    if not localFilePath
      localFilePath = @projectPath

    localFilePath = path.resolve(localFilePath,
                                path.relative(@settings.target, targetFilePath))

    errorHandler = (err) =>
      @logger.error err

    @_getConnection (err, c) =>
      return errorHandler err if err

      end = @logger.log "Download: #{targetFilePath} to #{localFilePath} ..."

      mkdirp = require "mkdirp" if not mkdirp
      mkdirp path.dirname(localFilePath), (err) ->
        return errorHandler err if err

        c.get targetFilePath, (err, readableStream) ->
          return errorHandler err if err

          fs = require "fs-plus" if not fs
          writableStream = fs.createWriteStream(localFilePath)
          writableStream.on "unpipe", ->
            end()
            callback?()
          readableStream.pipe writableStream

  fetchFileTree: (localPath, callback) ->
    targetPath = path.join(@settings.target,
                          path.relative(@projectPath, localPath))
                          .replace(/\\/g, "/")
    isIgnore = @settings.isIgnore

    @_getConnection (err, c) ->
      return callback err if err

      files = []
      directories = 0

      directory = (dir) ->
        directories++
        c.list dir, (err, list) ->
          return callback err if err

          list?.forEach (item, i) ->
            files.push dir + "/" + item.name if item.type is "-" and not isIgnore(item.name, dir)
            directory dir + "/" + item.name if item.type is "d" and item.name not in [".", ".."]

          directories--
          callback null, files  if directories is 0

      directory(targetPath)

  _getConnection: (callback) ->
    {hostname, port, username, password} = @settings

    if @connection
      return callback null, @connection

    @logger.log "Connecting: #{username}@#{hostname}:#{port}"

    FtpConnection = require "ftp" if not FtpConnection

    connection = new FtpConnection
    wasReady = false

    connection.on "ready", ->
      wasReady = true
      callback null, connection

    connection.on "error", (err) =>
      unless wasReady
        callback err
      @connection = null

    connection.on "end", =>
      @connection = null

    connection.connect
      host: hostname
      port: port
      user: username
      password: password

    @connection = connection
