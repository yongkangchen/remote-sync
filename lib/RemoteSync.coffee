
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
    @initIgnore(@host)

  initIgnore: (host)->
    ignore = host.ignore?.split(",")
    host.isIgnore = (filePath, relativizePath) =>
      return false unless ignore

      relativizePath = @projectPath unless relativizePath
      filePath = path.relative relativizePath, filePath

      minimatch ?= require "minimatch"
      for pattern in ignore
        return true if minimatch filePath, pattern, { matchBase: true, dot: true }
      return false

  isIgnore: (filePath, relativizePath)->
    return @host.isIgnore(filePath, relativizePath)

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
    realPath = path.relative(@projectPath, localPath)
    realPath = path.join(@host.target, realPath).replace(/\\/g, "/")
    @getTransport().download(realPath)

  uploadFile: (filePath) ->
    return if @isIgnore(filePath)

    if not uploadCmd
      UploadListener = require "./UploadListener"
      uploadCmd = new UploadListener getLogger()

    uploadCmd.handleSave(filePath, @getTransport())
    for t in @getUploadMirrors()
      uploadCmd.handleSave(filePath, t)

  uploadFolder: (dirPath)->
    fs.traverseTree dirPath, @uploadFile.bind(@), =>
      return not @isIgnore(dirPath)

  uploadGitChange: (dirPath)->
    repos = atom.project.getRepositories()
    curRepo = null
    for repo in repos
      continue unless repo
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
