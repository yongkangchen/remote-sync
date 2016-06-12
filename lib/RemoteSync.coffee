path = require "path"
fs = require "fs-plus"
chokidar = require "chokidar"
isValidGlob = require "is-valid-glob"

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

  # init monitor function called on init of remote sync
  initMonitor: ()->
    _this = @
    setTimeout ->
      # add on observer to the tree view so we can re add styles
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

    # if not already init create a watcher
    if !watchChangeSet
      _this = @
      watcher.on('change', (path) ->
        _this.uploadFile(path)
      )
      watchChangeSet = true

  # function called to toggle monitor file/folder
  monitorFile: (dirPath, toggle = true, notifications = true)->
    return if !@fileExists(dirPath) # check if file exists
    fileName = @.monitorFileName(dirPath) #get just file name - used for notifations

    # check if path not alread being monitored
    if dirPath not in MonitoredFiles
      @.monitorWatch(dirPath) # monitor

      # if notifications
      if notifications
        @.monitorNotification(fileName,false,@.isDirectory(dirPath))

    # else if toggle is enabled
    else if toggle
      @.monitorUnwatch(dirPath) # un-monitor

      # if notifications
      if notifications
        @.monitorNotification(fileName,true,@.isDirectory(dirPath))

    # run monitor styles check
    @.monitorStyles()

  # creates monitoring of a glob string
  monitorGlob: (dirPath)->
    return if !isValidGlob(dirPath)
    console.log "monitor glob please", dirPath
    @.monitorWatch(dirPath)

  # basic monitor function
  # starts the watching of file/folder/glob/etc..
  monitorWatch: (dirPath)->
    if dirPath not in MonitoredFiles
      MonitoredFiles.push dirPath
      watcher.add(dirPath)

  # basic unmonitor function
  # unwatching of file/folder/glob/etc..
  monitorUnwatch: (dirPath)->
    if dirPath in MonitoredFiles
      watcher.unwatch(dirPath)
      index = MonitoredFiles.indexOf(dirPath)
      MonitoredFiles.splice(index, 1)

  # builds a string to output monitor notice
  monitorNotification: (fileName = "", watching = true, isFolder = false) ->
    notice  = if watching then "Unwatching" else "Watching"
    type    = if isFolder then "folder" else "file"
    message = "remote-sync: "+notice+" "+type+" - *"+fileName+"*"

    atom.notifications.addInfo message

  # monitor folder method calls the monitor file method passing in a folder path
  monitorFolder: (dirPath)->
    @.monitorFile(dirPath)

  # monitor styles
  # monitor styles makes sure that each folder/file has the correct css styles
  monitorStyles: ()->
    monitorFileClass  = 'file-monitoring'
    monitorFolderClass  = 'folder-monitoring'
    pulseClass    = 'pulse'
    filesMonitored = document.querySelectorAll '.'+monitorFileClass
    foldersMonitored = document.querySelectorAll '.'+monitorFolderClass

    #clean up styles

    # loop though all files removing any styles
    if filesMonitored != null and filesMonitored.length != 0
      for item in filesMonitored
        item.classList.remove monitorFileClass
        item.classList.remove pulseClass

    # loop though all folders removing any styles
    if foldersMonitored != null and foldersMonitored.length != 0
      for item in foldersMonitored
        item.classList.remove monitorFolderClass
        item.classList.remove pulseClass

    # loop though the monitored files list / contains all files/folders/glob
    for file in MonitoredFiles
      # escape a few things to make the strings safe
      location_path = file.replace(/(['"])/g, "\\$1"); #escape '
      location_path = location_path.replace(/\\/g, '\\\\'); #escape back-slash
      isDirectory = @.isDirectory(location_path) # check if path is file or folder

      #look up the path location in the tree-view
      icon_file = document.querySelector '[data-path="'+location_path+'"]'
      #check if found
      if icon_file != null
        #build some classes based upon directory type
        list_item = if isDirectory then icon_file.parentNode.parentNode else icon_file.parentNode #if directory check 2 parents high
        theClass = if isDirectory then monitorFolderClass else monitorFileClass # get the correct style class
        list_item.classList.add theClass # add the style class
        # if animation is enabled add class
        if atom.config.get("remote-sync.monitorFileAnimation")
          list_item.classList.add pulseClass

  # lists all current paths being watchedPaths
  # this list comes from the watcher not the monitorFilesList
  monitorFilesList: ()->
    files        = "" # empty var to hold strings
    watchedPaths = watcher.getWatched() # request all watched paths
    # loop thought all paths building a string
    for k,v of watchedPaths
      for file in watchedPaths[k]
        files += file+"<br/>"

    # if files list is not empty output which files are being watchedPaths
    # else inform that nothing is being watched
    if files != ""
      atom.notifications.addInfo "remote-sync: Currently watching:<br/>*"+files+"*"
    else
      atom.notifications.addWarning "remote-sync: Currently not watching any files"

  # method that checks if a file is found
  fileExists: (dirPath) ->
    file_name = @monitorFileName(dirPath)
    try
      exists = fs.statSync(dirPath)
      return true
    catch e
      atom.notifications.addWarning "remote-sync: cannot find *"+file_name+"* to watch"
      return false

  # method that checks is a directory
  isDirectory: (dirPath) ->
    if isGlob = isValidGlob(dirPath)
      return false
    if directory = fs.statSync(dirPath).isDirectory()
      return true

    return false

  # get the file name from the path
  monitorFileName: (dirPath)->
    file = dirPath.split('\\').pop().split('/').pop()
    return file

  # method called if any files watch files are found in the config
  initAutoFileWatch: (projectPath) ->
    _this = @
    if watchFiles.length != 0
      # runs thought the setup files then calls monitor files list on complete
      _this.setupAutoFileWatch filesName,projectPath for filesName in watchFiles
      setTimeout ->
        _this.monitorFilesList()
      , 1500
      return

  # runs thought all strings in the watch list to create a watch method
  setupAutoFileWatch: (filesName,projectPath) ->
    _this = @
    setTimeout ->
      if process.platform == "win32"
        filesName = filesName.replace(/\//g, '\\') # sort out windows slash escapes

      # get full path
      fullpath = projectPath + filesName.replace /^\s+|\s+$/g, ""

      # if is not a glob
      # pass to the monitor file function
      # else pass to the monitorGlob function
      if !isValidGlob(fullpath)
        _this.monitorFile(fullpath,false,false)
      else if isValidGlob(fullpath)
        _this.monitorGlob(fullpath);
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
    targetPath = path.join os.tmpDir(), "remote-sync"

    @getTransport().download realPath, targetPath, =>
      @diff localPath, targetPath

  diffFolder: (localPath)->
    os = require "os" if not os
    targetPath = path.join os.tmpDir(), "remote-sync"
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
