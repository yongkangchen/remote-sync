
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

  handleDelete: (localFilePath, transport) ->
    if not @queueDelete
      async = require "async" if not async
      @queueDelete = async.queue(@deleteFile.bind(@), 1)

    @queueDelete.push
      localFilePath: localFilePath
      transport: transport

  deleteFile: (task, callback) ->
    {localFilePath, transport} = task
    transport.delete localFilePath, callback

  uploadFile: (task, callback) ->
    {localFilePath, transport} = task
    transport.upload localFilePath, callback
