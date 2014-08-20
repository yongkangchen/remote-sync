
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
transport = null
statusView = null

uploadCmd = null
downloadCmd = null

module.exports =
  activate: ->
    Logger = require "./Logger"
    logger = new Logger "Remote Sync"

    statusView = new (require './StatusView')
    #TODO: support project path change
    configPath = path.join atom.project.getPath(), SETTINGS_FILE_NAME

    fs.exists configPath, (exists) ->
      if exists
        load()
      else
        statusView.update "question", "Not find config."

    atom.workspaceView.command "remote-sync:download-all", ->
      return logger.error("#{configPath} not exists") if not settings
      download(atom.project.getPath())

    atom.workspaceView.command "remote-sync:reload-config", ->
      load()

    atom.workspaceView.command 'remote-sync:upload', (e)->
      return logger.error("#{configPath} not exists") if not settings
      [localPath, isFile] = getSelectPath e
      if isFile
        handleSave(localPath)
      else
        uploadPath(localPath)

    atom.workspaceView.command 'remote-sync:download', (e)->
      return logger.error("#{configPath} not exists") if not settings
      [localPath, isFile] = getSelectPath e
      if isFile
        return if settings.isIgnore(localPath)
        localPath = atom.project.relativize(localPath)
        getTransport().download(path.resolve(settings.target, localPath))
      else
        download(localPath)

    atom.workspaceView.command 'remote-sync:diff', (e)->
      return logger.error("#{configPath} not exists") if not settings
      [localPath, isFile] = getSelectPath e
      os = require "os" if not os
      targetPath = path.join os.tmpDir(), "remote-sync-"+path.basename(localPath)
      diff = ->
        diffCmd = atom.config.get('remote-sync.difftoolCommand')
        exec    = require("child_process").exec if not exec
        exec "#{diffCmd} #{localPath} #{targetPath}", (err)->
          logger.error """Check the field value of difftool Command in your settings (remote-sync).
           Command error: #{err}
           command: #{diffCmd} #{localPath} #{targetPath}
           """

      if isFile
        return if settings.isIgnore(localPath)
        getTransport().download(path.resolve(settings.target, atom.project.relativize(localPath)), targetPath, diff)
      else
        download(localPath, targetPath, diff)

findFileParent = (node) ->
  parent = node.parent()
  return parent if parent.is('.file') or parent.is('.directory')
  findFileParent(parent)

getSelectPath = (e) ->
    selected = findFileParent($(e.target))
    [selected.view().getPath(), selected.is('.file')]

download = (localPath, targetPath, callback)->
  if not downloadCmd
    downloadCmd = require './commands/DownloadAllCommand'
  downloadCmd.run(logger, getTransport(), localPath, targetPath, callback)

minimatch = null
load = ->
  fs.readFile configPath,"utf8", (err, data)->
    return logger.error err if err

    try
      settings = JSON.parse(data)
    catch err
      deinit() if editorSubscription
      logger.error "load #{configPath}, #{err}"
      return

    console.log("setting: ", settings)

    if settings.uploadOnSave != false
      statusView.update "eye-watch"
      init() if not editorSubscription
    else
      statusView.update "eye-unwatch", "uploadOnSave disabled."
      unsubscript if editorSubscription

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
  editorSubscription = atom.workspace.eachEditor (editor) ->
    buffer = editor.getBuffer()
    bufferSavedSubscription = buffer.on 'after-will-be-saved', ->
      return unless buffer.isModified()
      f = buffer.getPath()
      return unless atom.project.contains(f)
      handleSave(f)

    bufferSubscriptionList[bufferSavedSubscription] = true
    buffer.on "destroyed", ->
      bufferSavedSubscription.off()
      delete bufferSubscriptionList[bufferSavedSubscription]

handleSave = (filePath) ->
  return if settings.isIgnore(filePath)

  if not uploadCmd
    UploadListener = require "./UploadListener"
    uploadCmd = new UploadListener logger
    console.log("handleSave, createUpload ")

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

  for bufferSavedSubscription, v of bufferSubscriptionList
    bufferSavedSubscription.off()

  bufferSubscriptionList = {}

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
