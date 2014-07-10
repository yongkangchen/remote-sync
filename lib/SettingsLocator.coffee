path = null
fs = null

SETTINGS_FILE_NAME = ".remote-sync.json"

module.exports =
class SettingsLocator
  locate: (sourceFilePath, callback, isDir) ->
    path = require "path" if not path
    fs = require "fs" if not fs

    if path.basename(sourceFilePath) is SETTINGS_FILE_NAME
      return callback null, null

    if isDir
      rootDirectory = sourceFilePath
    else
      rootDirectory = path.dirname sourceFilePath

    while rootDirectory isnt "/"
      settingsFilePath = path.join rootDirectory, SETTINGS_FILE_NAME
      if fs.existsSync settingsFilePath
        return @_readSettings settingsFilePath, sourceFilePath, callback
      rootDirectory = path.dirname rootDirectory

    callback null, null

  _readSettings: (settingsFilePath, sourceFilePath, callback) ->
    try
      rootDirectory = path.dirname settingsFilePath
      relativeFilePath = path.relative rootDirectory, sourceFilePath
      settings = JSON.parse(fs.readFileSync(settingsFilePath).toString())

      callback null,
        settingsFilePath: settingsFilePath
        rootDirectory: rootDirectory
        relativeFilePath: relativeFilePath
        settings: settings
    catch err
      callback err
