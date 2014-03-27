path = require "path"
fs = require "fs"


SETTINGS_FILE_NAME = ".remote-sync.json"


module.exports =
class SettingsLocator
  locate: (sourceFilePath, callback) ->
    if path.basename(sourceFilePath) is SETTINGS_FILE_NAME
      return callback null, null

    rootDirectory = sourceFilePath

    while rootDirectory isnt "/"
      rootDirectory = path.dirname rootDirectory
      settingsFilePath = path.join rootDirectory, SETTINGS_FILE_NAME

      if fs.existsSync settingsFilePath
        return @_readSettings settingsFilePath, sourceFilePath, callback

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
