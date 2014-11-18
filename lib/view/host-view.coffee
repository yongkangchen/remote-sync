{$, View, TextEditorView} = require 'atom'
fs = require 'fs-plus'

module.exports =
class ConfigView extends View
  @content: ->
    @div class: 'remote-sync overlay from-top', =>
      @label 'Transport'
      @div class: 'block', outlet: 'transportBlock', =>
        @div class: 'btn-group', =>
          @button class: 'btn  selected', outlet: 'scpTransportButton', 'SCP/SFTP'
          @button class: 'btn', outlet: 'ftpTransportButton', 'FTP'

      @label 'Hostname'
      @subview 'hostname', new TextEditorView(mini: true)

      @label 'Port'
      @subview 'port', new TextEditorView(mini: true)

      @label 'Target directory'
      @subview 'targetdir', new TextEditorView(mini: true)

      @label 'Username'
      @subview 'username', new TextEditorView(mini: true)

      @div class: 'block', outlet: 'authenticationButtonsBlock', =>
        @div class: 'btn-group', =>
          @button class: 'btn  selected', outlet: 'privateKeyButton', 'Private key'
          @button class: 'btn', outlet: 'passwordButton', 'Password'
          @button class: 'btn', outlet: 'userAgentButton', 'User agent'

      @div class: 'block', outlet: 'privateKeyBlock', =>
        @label 'Private key path'
        @subview 'privateKeyPath', new TextEditorView(mini: true)
        @label 'Private key passphrase (leave blank if unencrypted)'
        @subview 'privateKeyPassphrase', new TextEditorView(mini: true)

      @div class: 'block', outlet: 'passwordBlock', =>
        @label 'Password'
        @subview 'password', new TextEditorView(mini: true)

      @div class: 'block', outlet: 'buttonBlock', =>
        @button class: 'inline-block btn pull-right', outlet: 'cancelButton', 'Cancel'
        @button class: 'inline-block btn pull-right', outlet: 'saveButton', 'Save'

  initialize: (@host) ->
    console.log "initialize"
    console.log @host
    @on 'core:confirm', => @confirm()
    @saveButton.on 'click', => @confirm()

    @on 'core:cancel', => @detach()
    @cancelButton.on 'click', => @detach()

    @hostname.setText(@host.hostname ? "")
    @port.setText(@host.port)
    @targetdir.setText(@host.targetdir ? "/")
    @username.setText(@host.username ? "")
    @password.setText(@host.password ? "")
    @privateKeyPath.setText(@host.privateKeyPath ? "")
    @privateKeyPassphrase.setText(@host.passphrase ? "")

    @ftpTransportButton.on 'click', =>
      @ftpTransportButton.toggleClass('selected', true)
      @scpTransportButton.toggleClass('selected', false)
      @authenticationButtonsBlock.hide()
      @privateKeyBlock.hide()
      @passwordBlock.show()
      @port.setText(@host.port)
      if @host.transport isnt "ftp"
        @port.setText("21")

    @scpTransportButton.on 'click', =>
      @scpTransportButton.toggleClass('selected', true)
      @ftpTransportButton.toggleClass('selected', false)
      @authenticationButtonsBlock.show()
      @privateKeyButton.click()
      @port.setText(@host.port)
      if @host.transport isnt "scp"
        @port.setText("22")

    @privateKeyButton.on 'click', =>
      @privateKeyButton.toggleClass('selected', true)
      @userAgentButton.toggleClass('selected', false)
      @passwordButton.toggleClass('selected', false)
      @passwordBlock.hide()
      @privateKeyBlock.show()
      @privateKeyPath.focus()

    @passwordButton.on 'click', =>
      @privateKeyButton.toggleClass('selected', false)
      @userAgentButton.toggleClass('selected', false)
      @passwordButton.toggleClass('selected', true)
      @privateKeyBlock.hide()
      @passwordBlock.show()
      @password.focus()

    @userAgentButton.on 'click', =>
      @privateKeyButton.toggleClass('selected', false)
      @userAgentButton.toggleClass('selected', true)
      @passwordButton.toggleClass('selected', false)
      @passwordBlock.hide()
      @privateKeyBlock.hide()

  attach: ->
    atom.workspaceView.append(this)
    @scpTransportButton.click()
    if @host.transport is "scp"
      @scpTransportButton.click()
      if @host.useAgent
        @userAgentButton.click()
      else if @host.privateKeyPath
        @privateKeyButton.click()
      else
        @passwordButton.click()
    else
      @ftpTransportButton.click()

  confirm: ->
    @host.hostname = @hostname.getText()
    @host.port = @port.getText()
    @host.targetdir = @targetdir.getText()
    @host.username = @username.getText()
    @host.privateKeyPath = ""
    @host.passphrase = ""
    @host.password = if @passwordButton.hasClass('selected') then @password.getText() else ""
    @host.useAgent = false
    if @scpTransportButton.hasClass('selected')
      @host.transport = "scp"
      if @privateKeyButton.hasClass('selected')
        @host.privateKeyPath = fs.absolute(@privateKeyPath.getText())
        @host.passphrase = @privateKeyPassphrase.getText()
      else if @userAgentButton.hasClass('selected')
        @host.useAgent = true
    else
      @host.transport = "ftp"
    @host.saveJSON()
    @detach()
