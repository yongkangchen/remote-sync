fs = require 'fs-plus'
EventEmitter = require("events").EventEmitter

module.exports =
class Host
  constructor: (@configPath, @emitter) ->
    return if !fs.existsSync @configPath
    try
      data = fs.readFileSync @configPath, "utf8"
      settings = JSON.parse(data)
      for k, v of settings
        this[k] = v
    catch err
      console.log "load #{configPath}, #{err}"

    @port?= ""
    @port = @port.toString()
    @ignore = @ignore.join(", ") if @ignore

  saveJSON: ->
    configPath = @configPath
    emitter = @emitter

    @configPath = undefined
    @emitter = undefined

    @ignore?= ".remote-sync.json,.git/**"
    @ignore = @ignore.split(',')
    @ignore = (val.trim() for val in @ignore when val)

    @transport?="scp"

    fs.writeFile configPath, JSON.stringify(this, null, 2), (err) ->
      if err
        console.log("Failed saving file #{configPath}")
      else
        emitter.emit 'configured'
