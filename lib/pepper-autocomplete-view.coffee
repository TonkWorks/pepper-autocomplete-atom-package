crypto = require 'crypto'
path = require 'path'
{$, $$$, ScrollView, TextEditor} = require 'atom'
_ = require 'underscore-plus'

window.jQuery = $

module.exports =
class PepperHtmlPreviewView extends ScrollView
  atom.deserializers.add(this)
  atom.commands.add 'atom-workspace', "pepper-autocomplete-view:complete", => @complete()
  @ensureUserInfo

  if atom.workspace?
    editor = atom.workspace.getActiveTextEditor()
    if editor?
      editor.pepper_ignore_changes = false
      editor.pepper_tabs = 0
      editor.pepper_last_completion = ""

  @complete: ->
    editor = atom.workspace.getActiveTextEditor()
    if editor?
      if document.getElementById("pepper_frame").contentWindow?
          editor.pepper_ignore_changes = true
          if editor.pepper_tabs > 0
            editor.undo()

          row = editor.getCursorScreenPosition().row
          current_line = editor.lineTextForScreenRow(row)
          completion_string = document.getElementById("pepper_frame").contentWindow.pepper.tab_complete_string(current_line, editor.pepper_tabs)
          editor.insertText(completion_string)

          editor.pepper_tabs += 1

          editor.pepper_ignore_changes = false

  @deserialize: (state) ->
    new PepperHtmlPreviewView(state)

  @content: ->
    @div class: 'pepper-autocomplete native-key-bindings', tabindex: -1

  constructor: ({@editorId, filePath}) ->
    super
    if @editorId?
      @resolveEditor(@editorId)
    else
      if atom.workspace?
        @subscribeToFilePath(filePath)
      else
        @subscribe atom.packages.once 'activated', =>
          @subscribeToFilePath(filePath)

  serialize: ->
    deserializer: 'PepperHtmlPreviewView'
    filePath: @getPath()
    editorId: @editorId

  destroy: ->
    @unsubscribe()

  subscribeToFilePath: (filePath) ->
    @trigger 'title-changed'
    @handleEvents()
    @renderHTML()

  resolveEditor: (editorId) ->
    resolve = =>
      @editor = @editorForId(editorId)
      @current_editor = @editor
      if @editor?
        @trigger 'title-changed' if @editor?
        @handleEvents()
      else
        # The editor this preview was created for has been closed so close
        # this preview since a preview cannot be rendered without an editor
        @parents('.pane').view()?.destroyItem(this)

    if atom.workspace?
      resolve()
    else
      @subscribe atom.packages.once 'activated', =>
        resolve()
        @renderHTML()

  editorForId: (editorId) ->
    for editor in atom.workspace.getEditors()
      return editor if editor.id?.toString() is editorId.toString()
    null

  handleEvents: ->
    changeHandler = =>
      #@renderHTML()
      if @editor?
        @updateResults()

      pane = atom.workspace.paneForUri(@getUri())
      if pane? and pane isnt atom.workspace.getActivePane()
        pane.activateItem(this)

    # Track the current pane item, update current editor
    @subscribe(atom.workspace.observeActivePaneItem(@updateCurrentEditor))

    #if @editor?
    @subscribe(@editor.onDidChangeCursorPosition changeHandler)
    #@subscribe @editor, 'path-changed', => @trigger 'title-changed'



  updateCurrentEditor: (currentPaneItem) =>
      return if not currentPaneItem? or currentPaneItem is @editor
      return unless @paneItemIsValid(currentPaneItem)
      @editor = currentPaneItem
      @subscribe(@editor.onDidChangeCursorPosition  => @updateResults())

  paneItemIsValid: (paneItem) ->
    return false unless paneItem?
    return paneItem instanceof TextEditor

  renderHTML: ->
    @showLoading()
    if @editor?
      @renderHTMLCode(@editor.getText())

  renderHTMLCode: (text) ->
    iframe = document.createElement("iframe")
    iframe.id = "pepper_frame"
    iframe.src = "http://pepper-autocomplete.com/results"#"http://localhost/results"
    @html $ iframe

    document.getElementById("pepper_frame").contentWindow.atomClientConsole = @atomClientConsole
    document.getElementById("pepper_frame").contentWindow.atomClientExternalBrowser = @atomClientExternalBrowser
    document.getElementById("pepper_frame").contentWindow.atomClientSetKey = @atomClientSetKey
    document.getElementById("pepper_frame").contentWindow.atomClientGetKey = @atomClientGetKey



  updateResults: ->

    if @editor.pepper_ignore_changes is true
      return
    else
      row = @editor.getCursorScreenPosition().row
      line_text = @editor.lineTextForScreenRow(row)

      user_id = localStorage.getItem('pepper-autocomplete.userId')
      key = atom.config.get('pepper-autocomplete.LicenseKey')

      #document.getElementById("pepper_frame").pepper.context_change line_text, user_id, key
      if document?
        if document.getElementById("pepper_frame").contentWindow.pepper?
          document.getElementById("pepper_frame").contentWindow.pepper.context_change line_text, user_id, key
      #@trigger('pepper-autocomplete:html-changed')

      @editor.pepper_last_completion = ""
      @editor.pepper_tabs = 0

  getTitle: ->
    "Pepper Autocomplete"

  getUri: ->
    "pepper-autocomplete://editor/#{@editorId}"

  getPath: ->
    if @editor?
      @editor.getPath()

  showError: (result) ->
    failureMessage = result?.message

    @html $$$ ->
      @h2 'Pepper Autocomplete Failed'
      @h3 failureMessage if failureMessage?

  showLoading: ->
    @html $$$ ->
      @div class: 'atom-html-spinner', 'Loading HTML Preview\u2026'


  atomClientConsole: (text) ->
    console.log text

  atomClientExternalBrowser: (url) ->
    require('shell').openExternal url

  atomClientSetKey: (key) ->
    atom.config.set('pepper-autocomplete.LicenseKey', key)

  atomClientGetKey: ->
    return atom.config.get('pepper-autocomplete.LicenseKey')

  ensureUserInfo: (callback) ->
    if localStorage.getItem('pepper-autocomplete.toggleUserID')
        if localStorage.getItem('pepper-autocomplete.userId')
          callback()
        else if atom.config.get('pepper-autocomplete.userId')
          # legacy. Users who had the metrics id in their config file
          localStorage.setItem('pepper-autocomplete.userId', atom.config.get('pepper-autocomplete.userId'))
          callback()
        else
          @createUserId (userId) =>
            localStorage.setItem('pepper-autocomplete.userId', userId)
            callback()


  createUserId: (callback) ->
    createUUID = -> callback require('node-uuid').v4()
    try
      require('getmac').getMac (error, macAddress) =>
        if error?
          createUUID()
        else
          callback crypto.createHash('sha1').update(macAddress, 'utf8').digest('hex')
    catch e
      createUUID()
