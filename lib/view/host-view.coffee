{$, View, TextEditorView} = require 'atom-space-pen-views'
{CompositeDisposable} = require 'atom'

module.exports =
class ConfigView extends View
  panel: null

  @content: ->
    @div class: 'remote-sync remote-sync-host-settings', =>
      @div class: 'row', =>
        @div class:'block block-transports col-md-6', =>
          @div class: 'block-transport-btns', =>
            @div class: 'btn-group', outlet: 'transportGroup', =>
              @button class: 'btn  selected', targetBlock: 'authenticationButtonsBlock', 'SCP/SFTP'
              @button class: 'btn', targetBlock:'ftpPasswordBlock', 'FTP'

        @div class: 'block block-advanced-toggle col-md-6', =>
          @div class: 'pull-right', =>
            @button class: 'btn btn-advanced-toggle', outlet: 'advancedToggle', 'Addvanced Options'

      @div class: 'block block-non-advanced', =>
        @div class: 'block block-details panel panel-default', =>
          @div class: 'panel-body', =>
            @div class: 'panel-heading', style:'margin-bottom:10px;', =>
              @text 'Basic information'

            @label 'Hostname'
            @subview 'hostname', new TextEditorView(mini: true)

            @label 'Port'
            @subview 'port', new TextEditorView(mini: true)

            @label 'Target directory'
            @subview 'target', new TextEditorView(mini: true)

            @label 'Username'
            @subview 'username', new TextEditorView(mini: true)

        @div class: 'block block-authentication panel panel-default', =>
          @div class: 'panel-body', =>

            @div class: 'panel-heading', style:'margin-bottom:10px;', =>
              @text 'Authentication'

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

      @div class: 'block block-advanced panel panel-default', style: 'display:none', =>
        @div class: 'panel-body', =>

          @div class: 'panel-heading', style:'margin-bottom:10px;', =>
            @text 'Advanced options'

          @label 'Watch automatically'
          @subview 'watch', new TextEditorView(mini: true, placeholderText: "Files that will be automatically watched on project open")

          @label 'Ignore Paths'
          @subview 'ignore', new TextEditorView(mini: true, placeholderText: "Default: .remote-sync.json, .git/**")

          @div class: 'block block-advanced-extras', =>
            @div class:'checkbox checkbox-uploadonsave', =>
              @label " uploadOnSave", =>
                @input type: 'checkbox', outlet: 'uploadOnSave'

            @div class:'checkbox checkbox-useAtomicWrites', =>
              @label " useAtomicWrites", =>
                @input type: 'checkbox', outlet: 'useAtomicWrites'

            @div class:'checkbox checkbox-deleteLocal', =>
              @label " Delete local file/folder upon remote delete", =>
                @input type: 'checkbox', outlet: 'deleteLocal'

            @div class:'checkbox checkbox-ftps', =>
              @label " Use FTPS (only used for FTP)", =>
                @input type: 'checkbox', outlet: 'useFTPS'

      @div class: 'row', =>
        @div class: 'block block-end-button col-md-12', =>
          @div class: 'pull-right', =>
            @button class: 'inline-block-tight btn btn-danger', outlet: 'cancelButton', click: 'close', 'Cancel'
            @button class: 'inline-block-tight btn btn-success', outlet: 'saveButton', click: 'confirm', 'Save'

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

    @advancedToggle.on 'click', (e)=>
      btn = $(e.target)
      btn.toggleClass('selected')
      $('.block-advanced').toggle()
      $('.block-non-advanced').toggle()
      $('.block-transport-btns').toggle()


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
    @useAtomicWrites.prop('checked', @host.useAtomicWrites)
    @deleteLocal.prop('checked', @host.deleteLocal)
    @useFTPS.prop('checked', @host.useFTPS)

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
    @host.useAtomicWrites = @useAtomicWrites.prop('checked')
    @host.deleteLocal = @deleteLocal.prop('checked')
    @host.useFTPS = @useFTPS.prop('checked')

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
