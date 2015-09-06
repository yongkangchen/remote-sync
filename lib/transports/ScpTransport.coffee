SSHConnection = null
mkdirp = null
fs = null
path = require "path"

module.exports =
class ScpTransport
  constructor: (@logger, @settings, @projectPath) ->

  dispose: ->
    if @connection
      @connection.end()
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

      c.sftp (err, sftp) ->
        return errorHandler err if err

        c.exec "rm -rf \"#{targetFilePath}\"", (err) ->
          return errorHandler err if err

          end()
          sftp.end()
          callback()

  upload: (localFilePath, callback) ->
    fs = require "fs" if not fs
    targetFilePath = path.join(@settings.target,
                          path.relative(fs.realpathSync(@projectPath), fs.realpathSync(localFilePath)))
                          .replace(/\\/g, "/")

    errorHandler = (err) =>
      @logger.error err
      callback()

    @_getConnection (err, c) =>
      return errorHandler err if err

      end = @logger.log "Upload: #{localFilePath} to #{targetFilePath} ..."

      c.sftp (err, sftp) ->
        return errorHandler err if err

        c.exec "mkdir -p \"#{path.dirname(targetFilePath)}\"", (err) ->
          return errorHandler err if err

          sftp.fastPut localFilePath, targetFilePath, (err) ->
            return errorHandler err if err

            end()

            sftp.end()
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

      c.sftp (err, sftp) ->
        return errorHandler err if err
        mkdirp = require "mkdirp" if not mkdirp
        mkdirp path.dirname(localFilePath), (err) ->
          return errorHandler err if err

          sftp.fastGet targetFilePath, localFilePath, (err) ->
            return errorHandler err if err

            end()

            sftp.end()
            callback?()

  fetchFileTree: (localPath, callback) ->
    {target, isIgnore} = @settings

    targetPath = path.join(target,
                          path.relative(@projectPath, localPath))
                          .replace(/\\/g, "/")


    @_getConnection (err, c) ->
      return callback err if err

      c.exec "find \"#{targetPath}\" -type f", (err, result) ->
        return callback err if err

        buf = ""
        result.on "data", (data) -> buf += data.toString()
        result.on "end", ->
          files = buf.split("\n").filter((f) ->
            return f and not isIgnore(f, target))

          callback null, files

  _getConnection: (callback) ->
    {hostname, port, username, password, keyfile, useAgent, passphrase, readyTimeout} = @settings

    if @connection
      return callback null, @connection

    @logger.log "Connecting: #{username}@#{hostname}:#{port}"

    SSHConnection = require "ssh2" if not SSHConnection

    connection = new SSHConnection
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

    if keyfile
      fs = require "fs" if not fs
      privateKey = fs.readFileSync keyfile
    else
      privateKey = null

    connection.connect
      host: hostname
      port: port
      username: username
      password: password
      privateKey: privateKey
      passphrase: passphrase
      readyTimeout: readyTimeout
      agent: if useAgent then process.env['SSH_AUTH_SOCK'] else null

    @connection = connection
