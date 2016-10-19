
minimatch = null
async = null

module.exports =
class UploadListener
  handleSave: (localFilePath, transport) ->
    @handleAction localFilePath, transport, 'upload'

  handleDelete: (localFilePath, transport) ->
    @handleAction localFilePath, transport, 'delete'

  handleAction: (localFilePath, transport, action) ->
    if not @queue
      async = require "async" if not async
      @queue = async.queue(@processFile.bind(@), 1)


    if @queue.length()
      task = @queue._tasks.head
      while task
       if task.data.localFilePath == localFilePath && task.data.action == action && task.data.transport.settings.transport == transport.settings.transport && task.data.transport.settings.hostname == transport.settings.hostname && task.data.transport.settings.port == transport.settings.port && task.data.transport.settings.target == transport.settings.target
         task.data.discard = true
       task = task.next

    @queue.resume()

    @queue.push
      localFilePath: localFilePath
      transport: transport
      action: action
      discard: false

  processFile: (task, callback) ->
    {localFilePath, transport, action, discard} = task

    cb = (err) =>
      if err
        @queue.pause()
        @queue.unshift task
      callback(err)

    if discard
      callback()
      return

    if action == 'upload'
      transport.upload localFilePath, cb
    else
      transport.delete localFilePath, cb
