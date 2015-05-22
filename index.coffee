CompositeDisposable = null
path = null
$ = null

getEventPath = (e)->
  $ ?= require('atom-space-pen-views').$
  
  target = $(e.target).closest('.file, .directory, .tab')[0]
  target ?= atom.workspace.getActiveTextEditor()
  
  fullPath = target?.getPath()
  return [] unless fullPath
  
  [projectPath, relativePath] = atom.project.relativizePath(fullPath)
  return [projectPath, fullPath]

projectDict = null
disposables = null
RemoteSync = null
initProject = (projectPaths)->
  disposes = []
  for projectPath of projectDict
    disposes.push projectPath if projectPaths.indexOf(projectPath) == -1

  for projectPath in disposes
    projectDict[projectPath].dispose()
    delete projectDict[projectPath]
  
  for projectPath in projectPaths
    RemoteSync ?= require "./lib/RemoteSync"
    projectDict[projectPath] ?= RemoteSync.create(projectPath)
  
handleEvent = (e, cmd)->
  [projectPath, fullPath] = getEventPath(e)
  return unless projectPath
  
  projectObj = projectDict[projectPath]
  projectObj[cmd]?(fullPath)
  
reload = (projectPath)->
  projectDict[projectPath]?.dispose()
  projectDict[projectPath] = RemoteSync.create(projectPath)

configure = (e)->
  [projectPath] = getEventPath(e)
  return unless projectPath
  
  RemoteSync ?= require "./lib/RemoteSync"
  RemoteSync.configure projectPath, -> reload(projectPath)

module.exports =
  config:
    logToConsole:
      type: 'boolean'
      default: false
      title: 'Log to console'
      description: 'Log messages to the console instead of the status view at the bottom of the window'
    difftoolCommand:
      type: 'string'
      default: ''
      title: 'Diff tool command'
      description: 'The command to run for your diff tool'
    configFileName:
      type: 'string'
      default: '.remote-sync.json'
      
  activate: (state) ->
    projectDict = {}
    initProject(atom.project.getPaths())
    
    CompositeDisposable ?= require('atom').CompositeDisposable
    disposables = new CompositeDisposable
    
    disposables.add atom.commands.add('atom-workspace', {
      'remote-sync:upload-folder': (e)-> handleEvent(e, "uploadFolder")
      'remote-sync:upload-file': (e)-> handleEvent(e, "uploadFile")
      'remote-sync:download-file': (e)-> handleEvent(e, "downloadFile")
      'remote-sync:download-folder': (e)-> handleEvent(e, "downloadFolder")
      'remote-sync:diff-file': (e)-> handleEvent(e, "diffFile")
      'remote-sync:diff-folder': (e)-> handleEvent(e, "diffFolder")
      'remote-sync:upload-git-change': (e)-> handleEvent(e, "uploadGitChange")
      'remote-sync:configure': configure
    })
    
    disposables.add atom.project.onDidChangePaths (projectPaths)->
      initProject(projectPaths)
    
    disposables.add atom.workspace.observeTextEditors (editor) ->
      onDidSave = editor.onDidSave (e) ->
        fullPath = e.path
        [projectPath, relativePath] = atom.project.relativizePath(fullPath)
        return unless projectPath
        
        projectObj = projectDict[projectPath]
        return unless projectObj
        
        if fullPath == projectObj.configPath
          projectObj = reload(projectPath)
        
        return unless projectObj.host.uploadOnSave
        projectObj.uploadFile(fullPath)
        
      
      onDidDestroy = editor.onDidDestroy ->
        disposables.remove onDidSave
        disposables.remove onDidDestroy
        onDidDestroy.dispose()
        onDidSave.dispose()
        
      disposables.add onDidSave
      disposables.add onDidDestroy

  deactivate: ->
    disposables.dispose()
    disposables = null
    for projectPath, obj of projectDict
      obj.dispose()
    projectDict = null