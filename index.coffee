fs = require('fs-plus')

CompositeDisposable = null
path = null
$ = null

getEventPath = (e)->
  $ ?= require('atom-space-pen-views').$

  target = $(e.target).closest('.file, .directory, .tab')[0]
  target ?= atom.workspace.getActiveTextEditor()

  fullPath = target?.getPath?()
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
    try
        projectPath = fs.realpathSync(projectPath)
    catch err
        continue
    continue if projectDict[projectPath]
    RemoteSync ?= require "./lib/RemoteSync"
    obj = RemoteSync.create(projectPath)
    projectDict[projectPath] = obj if obj

handleEvent = (e, cmd)->
  [projectPath, fullPath] = getEventPath(e)
  return unless projectPath

  projectObj = projectDict[fs.realpathSync(projectPath)]
  projectObj[cmd]?(fs.realpathSync(fullPath))

reload = (projectPath)->
  projectDict[projectPath]?.dispose()
  projectDict[projectPath] = RemoteSync.create(projectPath)

configure = (e)->
  [projectPath] = getEventPath(e)
  return unless projectPath

  projectPath = fs.realpathSync(projectPath)
  RemoteSync ?= require "./lib/RemoteSync"
  RemoteSync.configure projectPath, -> reload(projectPath)

module.exports =
  config:
    logToConsole:
      type: 'boolean'
      default: false
      title: 'Log to console'
      description: 'Log messages to the console instead of the status view at the bottom of the window'
    autoHideLogPanel:
      type: 'boolean'
      default: false
      title: 'Hide log panel after transferring'
      description: 'Hides the status view at the bottom of the window after the transfer operation is done'
    foldLogPanel:
      type: 'boolean'
      default: false
      title: 'Fold log panel by default'
      description: 'Shows only one line in the status view'
    monitorFileAnimation:
      type: 'boolean'
      default: true
      title: 'Monitor file animation'
      description: 'Toggles the pulse animation for a monitored file'
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
    try
      initProject(atom.project.getPaths())
    catch
      atom.notifications.addError "RemoteSync Error",
      {dismissable: true, detail: "Failed to initalise RemoteSync"}

    CompositeDisposable ?= require('atom').CompositeDisposable
    disposables = new CompositeDisposable

    disposables.add atom.commands.add('atom-workspace', {
      'remote-sync:upload-folder': (e)-> handleEvent(e, "uploadFolder")
      'remote-sync:upload-file': (e)-> handleEvent(e, "uploadFile")
      'remote-sync:delete-file': (e)-> handleEvent(e, "deleteFile")
      'remote-sync:delete-folder': (e)-> handleEvent(e, "deleteFile")
      'remote-sync:download-file': (e)-> handleEvent(e, "downloadFile")
      'remote-sync:download-folder': (e)-> handleEvent(e, "downloadFolder")
      'remote-sync:diff-file': (e)-> handleEvent(e, "diffFile")
      'remote-sync:diff-folder': (e)-> handleEvent(e, "diffFolder")
      'remote-sync:upload-git-change': (e)-> handleEvent(e, "uploadGitChange")
      'remote-sync:monitor-file': (e)-> handleEvent(e, "monitorFile")
      'remote-sync:monitor-files-list': (e)-> handleEvent(e,"monitorFilesList")
      'remote-sync:configure': configure
    })

    disposables.add atom.project.onDidChangePaths (projectPaths)->
      initProject(projectPaths)

    disposables.add atom.workspace.observeTextEditors (editor) ->
      atom.packages.activatePackage('tree-view').then ((pkg) ->
        treeView = pkg.mainModule.treeView
        onDidSave = editor.onDidSave (e) ->
          fullPath = e.path
          [projectPath, relativePath] = atom.project.relativizePath(fullPath)
          return unless projectPath

          projectPath = fs.realpathSync(projectPath)
          projectObj = projectDict[projectPath]
          return unless projectObj

          if fs.realpathSync(fullPath) == fs.realpathSync(projectObj.configPath)
            projectObj = reload(projectPath)

          return unless projectObj.host.uploadOnSave
          projectObj.uploadFile(fs.realpathSync(fullPath))

        onDidDelete = treeView.onEntryDeleted (e) ->
          fullPath = e.path
          [projectPath, relativePath] = atom.project.relativizePath(fullPath)

          return unless projectPath

          projectPath = fs.realpathSync(projectPath)
          projectObj = projectDict[projectPath]
          return unless projectObj

          # if fs.realpathSync(fullPath) == fs.realpathSync(projectObj.configPath)
          #   projectObj = reload(projectPath)

          return unless projectObj.host.uploadOnSave
          remotePath = projectObj.host.target + relativePath
          projectObj.deleteFile(fullPath)
          return
        
        onDidRename = treeView.onEntryMoved (e) ->
          initialPath = e.initialPath
          newPath = e.newPath
          [projectPath, relativePath] = atom.project.relativizePath(newPath)
          console.log newPath, projectPath, relativePath
          return unless projectPath
    
          projectPath = fs.realpathSync(projectPath)
          projectObj = projectDict[projectPath]
          return unless projectObj
    
          # if fs.realpathSync(fullPath) == fs.realpathSync(projectObj.configPath)
          #   projectObj = reload(projectPath)
    
          return unless projectObj.host.uploadOnSave
          remotePath = projectObj.host.target + relativePath
          
          # rename the lazy way by deleting and re-uploading
          projectObj.uploadFile(fs.realpathSync(newPath))
          projectObj.deleteFile(initialPath)
          return
        
        onDidDestroy = editor.onDidDestroy ->
          disposables.remove onDidSave
          disposables.remove onDidDelete
          disposables.remove onDidRename
          disposables.remove onDidDestroy

          onDidSave.dispose()
          onDidDelete.dispose()
          onDidRename.dispose()
          onDidDestroy.dispose()

        disposables.add onDidSave
        disposables.add onDidDelete
        disposables.add onDidRename
        disposables.add onDidDestroy
      ), (reason) ->
        atom.notifications.addWarning 'The tree-view package is not loaded.', description: reason.message
        return


  deactivate: ->
    disposables.dispose()
    disposables = null
    for projectPath, obj of projectDict
      obj.dispose()
    projectDict = null
