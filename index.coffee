{Subscriber} = require 'emissary'
SSHConnection = require 'ssh2'
minimatch = require 'minimatch'
msgPanel = require 'atom-message-panel'
path = require 'path'
fs = require 'fs'


SETTINGS_FILE_NAME = ".remote-sync.json"


class RemoteSync
  Subscriber.includeInto @

  constructor: ->
    @subscribe atom.workspace.eachEditor (editor) =>
      buffer = editor.getBuffer()

      bufferSavedSubscription = @subscribe buffer, 'saved', =>
        @handleSave(buffer)

      @subscribe editor, 'destroyed', ->
        bufferSavedSubscription.off()

      @subscribe buffer, 'destroyed', =>
        @unsubscribe(buffer)

  handleSave: (buffer) ->
    return if path.basename(buffer.file.path) is SETTINGS_FILE_NAME

    rootDirectory = buffer.file.path

    while rootDirectory isnt "/"
      rootDirectory = path.dirname rootDirectory
      settingsFilePath = path.join rootDirectory, SETTINGS_FILE_NAME

      if fs.existsSync settingsFilePath
        filePath = path.relative(rootDirectory, buffer.file.path)
        settings = JSON.parse(fs.readFileSync(settingsFilePath).toString())
        @syncFile(rootDirectory, filePath, settings)
        break

  syncFile: (rootDirectory, filePath, settings) ->
    if settings.ignore
      settings.ignore = [settings.ignore] unless Array.isArray settings.ignore
      for pattern in settings.ignore
        if minimatch filePath, pattern
          return

    switch settings.transport
      when "scp"
        @syncFileViaScp rootDirectory, filePath, settings

  syncFileViaScp: (rootDirectory, filePath, settings) ->
    @openPanel()
    @log "Uploading \"#{filePath}\" to \"#{settings.hostname}\""

    c = new SSHConnection

    c.on 'ready', =>
      c.sftp (err, sftp) =>
        return @error err if err

        c.exec "mkdir -p #{settings.target}", (err) =>
          return @error err if err

          sftp.fastPut path.join(rootDirectory, filePath), path.join(settings.target, filePath), (err) =>
            return @error err if err

            @log "Uploaded successfuly"
            @destroyPanel()

            sftp.end()

    c.on 'error', (err) =>
      @error err

    c.connect
      host: settings.hostname
      username: settings.username
      password: settings.password

  openPanel: ->
    unless @panelOpened
      msgPanel.init "Remote Sync"
      @panelOpened = true

    if @destroyTimeout
      clearTimeout @destroyTimeout
      @destroyTimeout = null

  destroyPanel: ->
    @destroyTimeout = setTimeout =>
      msgPanel.destroy()
      @destroyTimeout = null
      @panelOpened = false
    , 2000

  log: (message) ->
    msgPanel.append.message(message)

  error: (message) ->
    msgPanel.append.message("Error: #{message.message}")


module.exports =
  activate: (state) ->
    new RemoteSync
