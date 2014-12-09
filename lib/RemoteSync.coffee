
path = require "path"
fs = require "fs-plus"
{$} = require "atom"
os = null
exec = null


SETTINGS_FILE_NAME = ".remote-sync.json"

logger = null
configPath = null

file = null
settings = null
editorSubscription = null
bufferSubscriptionList = {}
bufferSubscriptionListKey = 0
transport = null
statusView = null
HostView = null
HostModel = null
EventEmitter = null

uploadCmd = null
downloadCmd = null

module.exports =
  activate: ->
    Logger = require "./Logger"
    logger = new Logger "Remote Sync"

    statusView = new (require './view/StatusView')
    #TODO: support project path change
    configPath = path.join atom.project.getPath(), SETTINGS_FILE_NAME

    fs.exists configPath, (exists) ->
      if exists
        load()
      else
        statusView.update "question", "Couldn't find config."

    atom.workspaceView.command "remote-sync:download-all", ->
      return if checkSetting()
      download(atom.project.getPath())

    atom.workspaceView.command "remote-sync:reload-config", ->
      load()

    atom.workspaceView.command 'remote-sync:upload-folder', (e)->
      return if checkSetting()
      uploadPath(getEventPath(e))

    atom.workspaceView.command 'remote-sync:upload-git-change', (e)->
      return if checkSetting()
      repo = atom.project.getRepo()
      return unless repo
      workingDirectory = repo.getWorkingDirectory()
      for filePath, status of repo.statuses
        handleSave(path.join(workingDirectory, filePath)) if status != 512

    atom.workspaceView.command 'remote-sync:upload-file', (e)->
      return if checkSetting()
      handleSave(getEventPath(e))

    atom.workspaceView.command 'remote-sync:download-file', (e)->
      return if checkSetting()
      localPath = getEventPath(e)
      return if settings.isIgnore(localPath)
      realPath = atom.project.relativize(localPath)
      realPath = path.join(settings.target, realPath).replace(/\\/g, "/")
      getTransport().download(realPath)

    atom.workspaceView.command 'remote-sync:download-folder', (e)->
      return if checkSetting()
      download(getEventPath(e))

    atom.workspaceView.command 'remote-sync:diff-file', (e)->
      return if checkSetting()
      localPath = getEventPath(e)
      return if settings.isIgnore(localPath)
      realPath = atom.project.relativize(localPath)
      realPath = path.join(settings.target, realPath).replace(/\\/g, "/")

      os = require "os" if not os
      targetPath = path.join os.tmpDir(), "remote-sync"

      getTransport().download realPath, targetPath, ->
        diff localPath, targetPath

    atom.workspaceView.command 'remote-sync:diff-folder', (e)->
      return if checkSetting()
      localPath = getEventPath(e)
      os = require "os" if not os
      targetPath = path.join os.tmpDir(), "remote-sync"

      download localPath, targetPath, ->
        diff localPath, targetPath

    atom.workspaceView.command 'remote-sync:configure', (e)->
      HostView ?= require './view/host-view'
      HostModel ?= require './model/host'
      EventEmitter ?= require("events").EventEmitter
      emitter = new EventEmitter()
      emitter.on "configured", () ->
        load()
      host = new HostModel(configPath, emitter)
      view = new HostView(host)
      view.attach()

diff = (localPath, targetPath) ->
  targetPath = path.join(targetPath, atom.project.relativize(localPath))
  diffCmd = atom.config.get('remote-sync.difftoolCommand')
  exec    = require("child_process").exec if not exec
  exec "#{diffCmd} #{localPath} #{targetPath}", (err)->
    return if not err
    logger.error """Check [difftool Command] in your settings (remote-sync).
     Command error: #{err}
     command: #{diffCmd} #{localPath} #{targetPath}
    """

checkSetting = ->
  if not settings
    logger.error("#{configPath} doesn't exist")
    return true
  return false

download = (localPath, targetPath, callback)->
  if not downloadCmd
    downloadCmd = require './commands/DownloadAllCommand'
  downloadCmd.run(logger, getTransport(), localPath, targetPath, callback)

minimatch = null
load = ->
  fs.readFile configPath,"utf8", (err, data) ->
    return logger.error err if err

    try
      settings = JSON.parse(data)
    catch err
      deinit() if editorSubscription
      logger.error "load #{configPath}, #{err}"
      return

    if settings.transport is "scp" or settings.transport is "sftp"
      transportText = "SFTP"
    else if settings.transport is "ftp"
      transportText = "FTP"
    else
      transportText = null

    unsubscript() if editorSubscription
    if settings.uploadOnSave != false
      statusView.update "eye-watch", null, transportText
      init() if not editorSubscription
    else
      statusView.update "eye-unwatch", "uploadOnSave disabled.", transportText

    if settings.ignore and not Array.isArray settings.ignore
      settings.ignore = [settings.ignore]

    settings.isIgnore = (filePath, relativizePath) ->
      return false if not settings.ignore
      if not relativizePath
        filePath = atom.project.relativize filePath
      else
        filePath = path.relative relativizePath, filePath
      minimatch = require "minimatch" if not minimatch
      for pattern in settings.ignore
        return true if minimatch filePath, pattern, { matchBase: true }
      return false

    if transport
      old = transport.settings
      if old.username != settings.username or old.hostname != settings.hostname or old.port != settings.port
        transport.dispose()
        transport = null
      else
        transport.settings = settings

init = ->
  editorSubscription = atom.workspace.observeTextEditors (editor) ->
    bufferSavedSubscription = editor.onDidSave (e) ->
      f = e.path
      return unless atom.project.contains(f)
      handleSave(f)
      load() if f == configPath

    key = bufferSubscriptionListKey++
    bufferSubscriptionList[key] = bufferSavedSubscription
    editor.onDidDestroy ->
      delete bufferSubscriptionList[key]
      bufferSavedSubscription.dispose()

handleSave = (filePath) ->
  return if settings.isIgnore(filePath)

  if not uploadCmd
    UploadListener = require "./UploadListener"
    uploadCmd = new UploadListener logger

  uploadCmd.handleSave(filePath, getTransport())

uploadPath = (dirPath)->
  onFile = (filePath)->
    handleSave(filePath)

  onDir = (dirPath)->
    return not settings.isIgnore(dirPath)

  fs.traverseTree dirPath, onFile, onDir

unsubscript = ->
  editorSubscription.off()
  editorSubscription = null

  for k, bufferSavedSubscription of bufferSubscriptionList
    bufferSavedSubscription.dispose()

  bufferSubscriptionList = {}
  bufferSubscriptionListKey = 0

deinit = ->
  unsubscript()
  settings = null

getTransport = ->
  return transport if transport
  if settings.transport is 'scp' or settings.type is 'sftp'
    ScpTransport = require "./transports/ScpTransport"
    transport = new ScpTransport logger, settings
  else if settings.transport is 'ftp'
    FtpTransport = require "./transports/FtpTransport"
    transport = new FtpTransport logger, settings

getEventPath = (e)->
  target = $(e.target).closest('.file, .directory, .tab')[0]
  target = atom.workspace.getActiveTextEditor() if not target
  target.getPath()
