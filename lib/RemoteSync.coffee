path = require "path"
fs = require "fs-plus"
chokidar = require "chokidar"
randomize = require "randomatic"

exec = null
minimatch = null

ScpTransport = null
FtpTransport = null

uploadCmd = null
DownloadCmd = null
Host = null

HostView = null
EventEmitter = null

MonitoredFiles = []
watchFiles     = {}
watchChangeSet = false
watcher        = chokidar.watch()


logger = null
getLogger = ->
  if not logger
    Logger = require "./Logger"
    logger = new Logger "Remote Sync"
  return logger

class RemoteSync
  constructor: (@projectPath, @configPath) ->
    Host ?= require './model/host'

    @host = new Host(@configPath)
    watchFiles = @host.watch?.split(",").filter(Boolean)
    @projectPath = path.join(@projectPath, @host.source) if @host.source
    if watchFiles?
      @initAutoFileWatch(@projectPath)
    @initIgnore(@host)
    @initMonitor()

  initIgnore: (host)->
    ignore = host.ignore?.split(",")
    host.isIgnore = (filePath, relativizePath) =>
      return true unless relativizePath or @inPath(@projectPath, filePath)
      return false unless ignore

      relativizePath = @projectPath unless relativizePath
      filePath = path.relative relativizePath, filePath

      minimatch ?= require "minimatch"
      for pattern in ignore
        return true if minimatch filePath, pattern, { matchBase: true, dot: true }
      return false

  isIgnore: (filePath, relativizePath)->
    return @host.isIgnore(filePath, relativizePath)

  inPath: (rootPath, localPath)->
    localPath = localPath + path.sep if fs.isDirectorySync(localPath)
    return localPath.indexOf(rootPath + path.sep) == 0

  dispose: ->
    if @transport
      @transport.dispose()
      @transport = null

  deleteFile: (filePath) ->
    return if @isIgnore(filePath)

    if not uploadCmd
      UploadListener = require "./UploadListener"
      uploadCmd = new UploadListener getLogger()

    uploadCmd.handleDelete(filePath, @getTransport())
    for t in @getUploadMirrors()
      uploadCmd.handleDelete(filePath, t)

    if @host.deleteLocal
      fs.removeSync(filePath)

  downloadFolder: (localPath, targetPath, callback)->
    DownloadCmd ?= require './commands/DownloadAllCommand'
    DownloadCmd.run(getLogger(), @getTransport(),
                                localPath, targetPath, callback)

  downloadFile: (localPath)->
    return if @isIgnore(localPath)
    realPath = path.relative(@projectPath, localPath)
    realPath = path.join(@host.target, realPath).replace(/\\/g, "/")
    @getTransport().download(realPath)

  uploadFile: (filePath) ->
    return if @isIgnore(filePath)

    if not uploadCmd
      UploadListener = require "./UploadListener"
      uploadCmd = new UploadListener getLogger()

    if @host.saveOnUpload
      for e in atom.workspace.getTextEditors()
        if e.getPath() is filePath and e.isModified()
          e.save()
          return if @host.uploadOnSave

    uploadCmd.handleSave(filePath, @getTransport())
    for t in @getUploadMirrors()
      uploadCmd.handleSave(filePath, t)

  uploadFolder: (dirPath)->
    fs.traverseTree dirPath, @uploadFile.bind(@), =>
      return not @isIgnore(dirPath)

  initMonitor: ()->
    _this = @
    setTimeout ->
      MutationObserver = window.MutationObserver or window.WebKitMutationObserver
      observer = new MutationObserver((mutations, observer) ->
        _this.monitorStyles()
        return
      )

      targetObject = document.querySelector '.tree-view'
      if targetObject != null
        observer.observe targetObject,
          subtree: true
          attributes: false
          childList: true
    , 250

  monitorFile: (dirPath, toggle = true, notifications = true)->
    return if !@fileExists(dirPath) && !@isDirectory(dirPath)

    fileName = @.monitorFileName(dirPath)
    if dirPath not in MonitoredFiles
      MonitoredFiles.push dirPath
      watcher.add(dirPath)
      if notifications
        atom.notifications.addInfo "remote-sync: Watching file - *"+fileName+"*"

      if !watchChangeSet
        _this = @
        watcher.on('change', (path) ->
          _this.uploadFile(path)
        )
        watcher.on('unlink', (path) ->
          _this.deleteFile(path)
        )
        watchChangeSet = true
    else if toggle
      watcher.unwatch(dirPath)
      index = MonitoredFiles.indexOf(dirPath)
      MonitoredFiles.splice(index, 1)
      if notifications
        atom.notifications.addInfo "remote-sync: Unwatching file - *"+fileName+"*"
    @.monitorStyles()

  monitorStyles: ()->
    monitorClass  = 'file-monitoring'
    pulseClass    = 'pulse'
    monitored     = document.querySelectorAll '.'+monitorClass

    if monitored != null and monitored.length != 0
      for item in monitored
        item.classList.remove monitorClass

    for file in MonitoredFiles
      file_name = file.replace(/(['"])/g, "\\$1");
      file_name = file.replace(/\\/g, '\\\\');
      icon_file = document.querySelector '[data-path="'+file_name+'"]'
      if icon_file != null
        list_item = icon_file.parentNode
        list_item.classList.add monitorClass
        if atom.config.get("remote-sync.monitorFileAnimation")
          list_item.classList.add pulseClass

  monitorFilesList: ()->
    files        = ""
    watchedPaths = watcher.getWatched()
    for k,v of watchedPaths
      for file in watchedPaths[k]
        files += file+"<br/>"
    if files != ""
      atom.notifications.addInfo "remote-sync: Currently watching:<br/>*"+files+"*"
    else
      atom.notifications.addWarning "remote-sync: Currently not watching any files"

  fileExists: (dirPath) ->
    file_name = @monitorFileName(dirPath)
    try
      exists = fs.statSync(dirPath)
      return true
    catch e
      atom.notifications.addWarning "remote-sync: cannot find *"+file_name+"* to watch"
      return false

  isDirectory: (dirPath) ->
    if directory = fs.statSync(dirPath).isDirectory()
      atom.notifications.addWarning "remote-sync: cannot watch directory - *"+dirPath+"*"
      return false

    return true

  monitorFileName: (dirPath)->
    file = dirPath.split('\\').pop().split('/').pop()
    return file

  initAutoFileWatch: (projectPath) ->
    _this = @
    if watchFiles.length != 0
      _this.setupAutoFileWatch filesName,projectPath for filesName in watchFiles
      setTimeout ->
        _this.monitorFilesList()
      , 1500
      return

  setupAutoFileWatch: (filesName,projectPath) ->
    _this = @
    setTimeout ->
      if process.platform == "win32"
        filesName = filesName.replace(/\//g, '\\')
      fullpath = projectPath + filesName.replace /^\s+|\s+$/g, ""
      _this.monitorFile(fullpath,false,false)
    , 250


  uploadGitChange: (dirPath)->
    repos = atom.project.getRepositories()
    curRepo = null
    for repo in repos
      continue unless repo
      workingDirectory = repo.getWorkingDirectory()
      if @inPath(workingDirectory, @projectPath)
        curRepo = repo
        break
    return unless curRepo

    isChangedPath = (path)->
      status = curRepo.getCachedPathStatus(path)
      return curRepo.isStatusModified(status) or curRepo.isStatusNew(status)

    fs.traverseTree dirPath, (path)=>
      @uploadFile(path) if isChangedPath(path)
    , (path)=> return not @isIgnore(path)

  createTransport: (host)->
    if host.transport is 'scp' or host.transport is 'sftp'
      ScpTransport ?= require "./transports/ScpTransport"
      Transport = ScpTransport
    else if host.transport is 'ftp'
      FtpTransport ?= require "./transports/FtpTransport"
      Transport = FtpTransport
    else
      throw new Error("[remote-sync] invalid transport: " + host.transport + " in " + @configPath)

    return new Transport(getLogger(), host, @projectPath)

  getTransport: ->
    return @transport if @transport
    @transport = @createTransport(@host)
    return @transport

  getUploadMirrors: ->
    return @mirrorTransports if @mirrorTransports
    @mirrorTransports = []
    if @host.uploadMirrors
      for host in @host.uploadMirrors
        @initIgnore(host)
        @mirrorTransports.push @createTransport(host)
    return @mirrorTransports

  diffFile: (localPath)->
    realPath = path.relative(@projectPath, localPath)
    realPath = path.join(@host.target, realPath).replace(/\\/g, "/")

    os = require "os" if not os
    targetPath = path.join os.tmpDir(), "remote-sync", randomize('A0', 16)

    @getTransport().download realPath, targetPath, =>
      @diff localPath, targetPath

  diffFolder: (localPath)->
    os = require "os" if not os
    targetPath = path.join os.tmpDir(), "remote-sync", randomize('A0', 16)
    @downloadFolder localPath, targetPath, =>
      @diff localPath, targetPath

  diff: (localPath, targetPath) ->
    return if @isIgnore(localPath)
    targetPath = path.join(targetPath, path.relative(@projectPath, localPath))
    diffCmd = atom.config.get('remote-sync.difftoolCommand')
    exec ?= require("child_process").exec
    exec "\"#{diffCmd}\" \"#{localPath}\" \"#{targetPath}\"", (err)->
      return if not err
      getLogger().error """Check [difftool Command] in your settings (remote-sync).
       Command error: #{err}
       command: #{diffCmd} #{localPath} #{targetPath}
      """

module.exports =
  create: (projectPath)->
    configPath = path.join projectPath, atom.config.get('remote-sync.configFileName')
    return unless fs.existsSync configPath
    return new RemoteSync(projectPath, configPath)

  configure: (projectPath, callback)->
    HostView ?= require './view/host-view'
    Host ?= require './model/host'
    EventEmitter ?= require("events").EventEmitter

    emitter = new EventEmitter()
    emitter.on "configured", callback

    configPath = path.join projectPath, atom.config.get('remote-sync.configFileName')
    host = new Host(configPath, emitter)
    view = new HostView(host)
    view.attach()
