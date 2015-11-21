{$, View, TextEditorView} = require 'atom-space-pen-views'
{CompositeDisposable} = require 'atom'

module.exports =
class ConfigView extends View
  panel: null

  @content: ->
    @div class: 'remote-sync', =>
      @div class:'block', =>
        @div class: 'btn-group', outlet: 'transportGroup', =>
          @button class: 'btn  selected', targetBlock: 'authenticationButtonsBlock', 'SCP/SFTP'
          @button class: 'btn', targetBlock:'ftpPasswordBlock', 'FTP'

      @label 'Hostname'
      @subview 'hostname', new TextEditorView(mini: true)

      @label 'Port'
      @subview 'port', new TextEditorView(mini: true)

      @label 'Target directory'
      @subview 'target', new TextEditorView(mini: true)

      @label 'Ignore Paths'
      @subview 'ignore', new TextEditorView(mini: true, placeholderText: "Default: .remote-sync.json, .git/**")

      @label 'Username'
      @subview 'username', new TextEditorView(mini: true)

      @div class: 'block', outlet: 'authenticationButtonsBlock', =>
        @div class: 'btn-group', =>
          @a class: 'btn  selected', targetBlock: 'privateKeyBlock', 'privatekey'
          @a class: 'btn', targetBlock: 'passwordBlock', 'password'
          @a class: 'btn', outlet: 'userAgentButton', 'useAgent'

        @div class: 'block', outlet: 'privateKeyBlock', =>
          @label 'Keyfile path'
          @subview 'privateKeyPath', new TextEditorView(mini: true)
          @label 'Passphrase'
          @subview 'privateKeyPassphrase', new TextEditorView(mini: true, placeholderText: "leave blank if private key is unencrypted")

        @div class: 'block', outlet: 'passwordBlock', style: 'display:none', =>
          @label 'Password'
          @subview 'password', new TextEditorView(mini: true)

      @div class: 'block', outlet: 'ftpPasswordBlock', style: 'display:none', =>
        @label 'Password'

      @div class:'block', =>
        @label " uploadOnSave", =>
          @input type: 'checkbox', outlet: 'uploadOnSave'

      @label " Delete local file/folder upon remote delete", =>
        @input type: 'checkbox', outlet: 'deleteLocal'

      @div class: 'block pull-right', =>
        @button class: 'inline-block-tight btn', outlet: 'cancelButton', click: 'close', 'Cancel'
        @button class: 'inline-block-tight btn', outlet: 'saveButton', click: 'confirm', 'Save'

  initialize: (@host) ->
    @disposables = new CompositeDisposable
    @disposables.add atom.commands.add 'atom-workspace',
        'core:confirm': => @confirm()
        'core:cancel': (event) =>
          @close()
          event.stopPropagation()

    @transportGroup.on 'click', (e)=>
      e.preventDefault()
      btn = $(e.target)
      targetBlock = btn.addClass('selected').siblings('.selected').removeClass('selected').attr("targetBlock")
      this[targetBlock].hide() if targetBlock

      targetBlock = btn.attr("targetBlock")
      this[targetBlock].show() if targetBlock
      @host.transport = btn.text().split("/")[0].toLowerCase()
      if @host.transport == "scp"
        @passwordBlock.append(@password)
      else
        @ftpPasswordBlock.append(@password)

    $('.btn-group .btn', @authenticationButtonsBlock).on 'click', (e)=>
      e.preventDefault()
      targetBlock = $(e.target).addClass('selected').siblings('.selected').removeClass('selected').attr("targetBlock")
      this[targetBlock].hide() if targetBlock

      targetBlock = $(e.target).attr("targetBlock")
      this[targetBlock].show().find(".editor").first().focus() if targetBlock

  attach: ->
    @panel ?= atom.workspace.addModalPanel item: this

    @find(".editor").each (i, editor)=>
      dataName = $(editor).prev().text().split(" ")[0].toLowerCase()
      $(editor).view().setText(@host[dataName] or "")

    @uploadOnSave.prop('checked', @host.uploadOnSave)
    @deleteLocal.prop('checked', @host.deleteLocal)
    $(":contains('"+@host.transport.toUpperCase()+"')", @transportGroup).click() if @host.transport
    if @host.transport is "scp"
      $('.btn-group .btn', @authenticationButtonsBlock).each (i, btn)=>
        btn = $(btn)
        return unless @host[btn.text()]
        btn.click()
        return false

  close: ->
    @detach()
    @panel.destroy()
    @panel = null
    @disposables.dispose()

  confirm: ->
    @host.uploadOnSave = @uploadOnSave.prop('checked')
    @host.deleteLocal = @deleteLocal.prop('checked')
    @find(".editor").each (i, editor)=>
      dataName = $(editor).prev().text().split(" ")[0].toLowerCase()
      view = $(editor).view()
      val = view.getText()
      val = undefined if val == "" or view.parent().isHidden() or view.parent().parent().isHidden()
      @host[dataName] = val

    if (@host.transport == undefined or @host.transport == "scp") and @userAgentButton.hasClass('selected')
      @host.useAgent = true
    else
      @host.useAgent = undefined

    @host.saveJSON()
    @close()
