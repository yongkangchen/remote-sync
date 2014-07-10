
minimatch = null
async = null

module.exports =
class UploadListener
  handleSave: (localFilePath, transport) ->
    if not @queue
      async = require "async" if not async
      @queue = async.queue(@uploadFile.bind(@), 1)

    @queue.push
      localFilePath: localFilePath
      transport: transport

  uploadFile: (task, callback) ->
    {localFilePath, transport} = task
    transport.upload localFilePath, callback
