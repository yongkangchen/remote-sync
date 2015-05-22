
path = require "path"
fs = require "fs-plus"

exec = null
minimatch = null

ScpTransport = null
FtpTransport = null

uploadCmd = null
DownloadCmd = null
Host = null

HostView = null
EventEmitter = null

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
    @ignore = @host.ignore.split(",")
  
  dispose: ->
    if @transport
      @transport.dispose()
      @transport = null

  isIgnore: (filePath, relativizePath) ->
    return false unless @ignore
    
    relativizePath = @projectPath unless relativizePath
    filePath = path.relative relativizePath, filePath

    minimatch ?= require "minimatch"
    for pattern in @ignore
      return true if minimatch filePath, pattern, { matchBase: true, dot: true }
    return false

  downloadFolder: (localPath, targetPath, callback)->
    DownloadCmd ?= require './commands/DownloadAllCommand'
    DownloadCmd.run(getLogger(), @getTransport(),
                                localPath, targetPath, callback)
  
  downloadFile: (localPath)->
    realPath = path.relative(@projectPath, localPath)
    realPath = path.join(@host.target, realPath).replace(/\\/g, "/")
    @getTransport().download(realPath)
    
  uploadFile: (filePath) ->
    return if @isIgnore(filePath)
    
    if not uploadCmd
      UploadListener = require "./UploadListener"
      uploadCmd = new UploadListener getLogger()

    uploadCmd.handleSave(filePath, @getTransport())

  uploadFolder: (dirPath)->
    fs.traverseTree dirPath, @uploadFile.bind(@), =>
      return not @isIgnore(dirPath)
  
  uploadGitChange: (dirPath)->
    repos = atom.project.getRepositories()
    curRepo = null
    for repo in repos
      workingDirectory = repo.getWorkingDirectory()
      if workingDirectory == @projectPath
        curRepo = repo
        break
    return unless curRepo
    
    isChangedPath = (path)->
      status = curRepo.getCachedPathStatus(path)
      return curRepo.isStatusModified(status) or curRepo.isStatusNew(status)
      
    fs.traverseTree dirPath, (path)=>
      @uploadFile(path) if isChangedPath(path)
    , (path)=> return not @isIgnore(path)
  
  getTransport: ->
    return @transport if @transport
    if @host.transport is 'scp' or @host.transport is 'sftp'
      ScpTransport ?= require "./transports/ScpTransport"
      Transport = ScpTransport
    else if @host.transport is 'ftp'
      FtpTransport ?= require "./transports/FtpTransport"
      Transport = FtpTransport
    else
      throw new Error("[remote-sync] invalid transport: " + @host.transport + " in " + @configPath)

    @transport = new Transport(getLogger(), @host,
                              @projectPath, @isIgnore.bind(@))

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
    targetPath = path.join(targetPath, path.relative(@projectPath, localPath))
    diffCmd = atom.config.get('remote-sync.difftoolCommand')
    exec ?= require("child_process").exec
    exec "#{diffCmd} \"#{localPath}\" \"#{targetPath}\"", (err)->
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