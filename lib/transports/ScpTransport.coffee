{MessagePanelView, PlainMessageView} = require "atom-message-panel"
SSHConnection = require "ssh2"
mkdirp = require "mkdirp"
path = require "path"


module.exports =
class ScpTransport
  constructor: (@logger) ->
    @connections = {}

  upload: (rootDirectory, relativeFilePath, settings, callback) ->
    localFilePath = path.join(rootDirectory, relativeFilePath)
    targetFilePath = path.join(settings.target, relativeFilePath)

    errorHandler = (err) =>
      @logger.error err
      callback()

    @_getConnection settings.hostname, settings.port, settings.username, settings.password, (err, c) =>
      return errorHandler err if err

      @logger.log "Uploading: #{relativeFilePath}"

      c.sftp (err, sftp) =>
        return errorHandler err if err

        c.exec "mkdir -p \"#{path.dirname(targetFilePath)}\"", (err) =>
          return errorHandler err if err

          sftp.fastPut localFilePath, targetFilePath, (err) =>
            return errorHandler err if err

            @logger.log "Uploaded: #{relativeFilePath}"

            sftp.end()
            callback()
    @connections = {}

  download: (rootDirectory, relativeFilePath, settings, callback) ->
    localFilePath = path.join(rootDirectory, relativeFilePath)
    targetFilePath = path.join(settings.target, relativeFilePath)

    errorHandler = (err) =>
      @logger.error err
      callback()

    @_getConnection settings.hostname, settings.port settings.username, settings.password, (err, c) =>
      return errorHandler err if err

      @logger.log "Downloading: #{relativeFilePath}"

      c.sftp (err, sftp) =>
        return errorHandler err if err

        mkdirp path.dirname(localFilePath), (err) =>
          return errorHandler err if err

          sftp.fastGet targetFilePath, localFilePath, (err) =>
            return errorHandler err if err

            @logger.log "Downloaded: #{relativeFilePath}"

            sftp.end()
            callback()

  fetchFileTree: (settings, callback) ->
    @_getConnection settings.hostname, settings.port, settings.username, settings.password, (err, c) =>
      return callback err if err

      c.exec "find \"#{settings.target}\" -type f", (err, result) ->
        return callback err if err

        buf = ""
        result.on "data", (data) -> buf += data.toString()
        result.on "end", ->
          targetRegexp = new RegExp "^#{settings.target}/"
          files = buf.split("\n")
            .filter((f) -> targetRegexp.test(f))
            .map((f) -> f.replace(targetRegexp, ""))
          callback null, files

  _getConnection: (hostname, port, username, password, callback) ->
    key = "#{username}@#{hostname}:#{port}"

    if @connections[key]
      return callback null, @connections[key]

    @logger.log "Connecting: #{key}"

    connection = new SSHConnection
    wasReady = false

    connection.on "ready", ->
      wasReady = true
      callback null, connection

    connection.on "error", (err) =>
      unless wasReady
        callback err
      @connections[key] = undefined

    connection.on "end", =>
      @connections[key] = undefined

    connection.connect
      host: hostname
      port: port
      username: username
      password: password

    @connections[key] = connection
