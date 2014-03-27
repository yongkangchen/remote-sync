{MessagePanelView, PlainMessageView} = require "atom-message-panel"
SSHConnection = require "ssh2"
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

    @_getConnection settings.hostname, settings.username, settings.password, (err, c) =>
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

  _getConnection: (hostname, username, password, callback) ->
    key = "#{username}@#{hostname}"

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
      username: username
      password: password

    @connections[key] = connection
