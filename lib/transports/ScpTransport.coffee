{MessagePanelView, PlainMessageView} = require "atom-message-panel"
SSHConnection = require "ssh2"
path = require "path"


module.exports =
class ScpTransport
  constructor: (@logger) ->

  upload: (rootDirectory, relativeFilePath, settings, callback) ->
    @logger.log "Uploading: #{relativeFilePath}"

    localFilePath = path.join(rootDirectory, relativeFilePath)
    targetFilePath = path.join(settings.target, relativeFilePath)

    errorHandler = (err) =>
      @logger.error err
      callback()

    c = new SSHConnection

    c.on "ready", =>
      c.sftp (err, sftp) =>
        return errorHandler err if err

        c.exec "mkdir -p \"#{path.dirname(targetFilePath)}\"", (err) =>
          return errorHandler err if err

          sftp.fastPut localFilePath, targetFilePath, (err) =>
            return errorHandler err if err

            @logger.log "Uploaded: #{relativeFilePath}"

            sftp.end()
            c.end()
            callback()

    c.on "error", errorHandler

    c.connect
      host: settings.hostname
      username: settings.username
      password: settings.password
