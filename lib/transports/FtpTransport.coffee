FTPConnection = null
mkdirp = null
fs = null
path = require "path"

module.exports =
class ScpTransport
  constructor: (@logger, @settings) ->

  dispose: ->
    if @connection
      @connection.raw.quit (err, data) =>
        @logger.error err if err
      @connection = null

  upload: (localFilePath, callback) ->
    targetFilePath = path.join(@settings.target,
                                path.relative(atom.project.getPath(), localFilePath))
                                .replace(/\\/g, "/")

    errorHandler = (err) =>
      @logger.error err
      callback()

    @_getConnection (err, c) =>
      return errorHandler err if err

      @logger.log "Uploading: #{localFilePath} to #{targetFilePath}"

      c.mkdir path.dirname(targetFilePath), true, (err) =>
        return errorHandler err if err

        c.put localFilePath, targetFilePath, (err) =>
          return errorHandler err if err

          @logger.log "Uploaded: #{localFilePath} to #{targetFilePath}"

          callback()

  download: (targetFilePath, localFilePath, callback) ->
    if not localFilePath
      localFilePath = atom.project.getPath()

    localFilePath = path.resolve(localFilePath,
                                path.relative(@settings.target, targetFilePath))

    errorHandler = (err) =>
      @logger.error err

    @_getConnection (err, c) =>
      return errorHandler err if err

      @logger.log "Downloading: #{targetFilePath} to #{localFilePath}"

      mkdirp = require "mkdirp" if not mkdirp
      mkdirp path.dirname(localFilePath), (err) =>
        return errorHandler err if err

        c.get targetFilePath, (err, readableStream) =>
          return errorHandler err if err

          fs = require "fs-plus" if not fs
          writableStream = fs.createWriteStream(localFilePath)
          writableStream.on "unpipe", =>
            @logger.log "Downloaded: #{targetFilePath} to #{localFilePath}"
            callback?()
          readableStream.pipe writableStream

  fetchFileTree: (localPath, callback) ->
    targetPath = path.join(@settings.target,
                          path.relative(atom.project.getPath(), localPath))
                          .replace(/\\/g, "/")
    {isIgnore} = @settings

    @_getConnection (err, c) ->
      return callback err if err

      c.list targetPath, (err, list) ->
        return callback err if err

        files = []
        for file, i in list
          if file.type is '-' and not isIgnore(file.name, targetPath)
            files.push targetPath + "/" + file.name

        callback null, files

  _getConnection: (callback) ->
    {hostname, port, username, password, keyfile, useAgent, passphrase} = @settings

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
