fs = require 'fs-plus'
EventEmitter = require("events").EventEmitter

module.exports =
class Host
  constructor: (@configPath, @emitter, @transport = "scp", @hostname = "", @port = "22", @targetdir = "/", @username = "", @password = "", \
  @privateKeyPath = "", @passphrase = "", @useAgent = false) ->
    return null if !fs.existsSync @configPath
    try
      data = fs.readFileSync @configPath, "utf8"
      settings = JSON.parse(data)
      @transport = settings.transport
      @hostname = settings.hostname
      @port = settings.port
      @targetdir = settings.target
      @username = settings.username
      @password = settings.password
      @privateKeyPath = settings.keyfile
      @passphrase = settings.passphrase
      @useAgent = settings.useAgent
    catch err
      console.log "load #{configPath}, #{err}"

  saveJSON: ->
    console.log(this)
    data = {
      transport : @transport,
      hostname : @hostname,
      port : @port,
      target : @targetdir,
      username : @username,
      ignore: [
        ".git/**"
      ]
    }
    data.password = @password if !!@password
    data.keyfile = @privateKeyPath if !!@privateKeyPath
    data.passphrase = @passphrase if !!@passphrase
    data.useAgent = @useAgent if @useAgent
    fs.writeFile @configPath, JSON.stringify(data, null, 2),
                (err) =>
                  if err
                    console.log("Failed saving file #{configPath}")
                  else
                    @emitter.emit 'configured'
