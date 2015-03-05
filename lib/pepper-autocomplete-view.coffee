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
    editor.pepper_ignore_changes = false
    editor.pepper_tabs = 0
    editor.pepper_last_completion = ""

  @complete: ->
    editor = atom.workspace.getActiveTextEditor()

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
    text = """
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
    <title>Editor</title>
    <style type="text/css" media="screen">
      body {
          overflow: hidden;
      }


      #auto_completion_screen {
          margin: 0;
          position: absolute;
          top: 0;
          bottom: 0;
          left: 0;
          right: 0;
          overflow-y: scroll;
      }



      .code_result {
          margin-bottom: 0px;

      }
    .card {
        padding: 4px;
    }


        .info_div_result {
        text-align: right;

    }


      .marker_highlight{
        position:absolute;
        background:rgba(100,100,200,0.5);
        z-index:20
      }


      			.error{
				text-align: center;
				margin-left: auto;
				margin-right: auto;
				width: 400px;
				background-color: #b0e0e6;
			}

    </style>
  </head>
  <body>

  <pre id="auto_completion_screen">Auto-Completion-Editor
  </pre>

      <script src="atom://pepper-autocomplete/media/jquery.js" type="text/javascript"></script>


      <!-- json -->
      <script src="atom://pepper-autocomplete/media/jquery.json-2.3.js" type="text/javascript"></script>

      <!-- ace -->
      <script src="atom://pepper-autocomplete/media/ace/src/ace.js" type="text/javascript"></script>

      <!-- results -->
      <script src="atom://pepper-autocomplete/media/results.js" type="text/javascript"></script>
      <script>

    var Range = ace.require("ace/range").Range
    window.pepper_tabs = 0
    window.pepper_last_completion = ""
    window.pepper_ignore_changes = false


    document.addEventListener('new-window', function(e) {
      c
      require('shell').openExternal(e.url);
    });
      </script>

  </body>
  </html>
    """

    webview = '<webview id="pepper_frame" src=' + "data:text/html;charset=utf-8,#{encodeURI(text)}" +  ' autosize="on" nodeintegration plugins></webview>'
    iframe = document.createElement("iframe")
    iframe.id = "pepper_frame"
    iframe.src = "data:text/html;charset=utf-8,#{encodeURI(text)}"
    @html $ iframe


  updateResults: ->

    if @editor.pepper_ignore_changes is true
      return
    else
      row = @editor.getCursorScreenPosition().row
      line_text = @editor.lineTextForScreenRow(row)

      user_id = localStorage.getItem('metrics.userId')
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



  ensureUserInfo: (callback) ->
    if localStorage.getItem('metrics.userId')
      callback()
    else if atom.config.get('metrics.userId')
      # legacy. Users who had the metrics id in their config file
      localStorage.setItem('metrics.userId', atom.config.get('metrics.userId'))
      callback()
    else
      @createUserId (userId) =>
        localStorage.setItem('metrics.userId', userId)
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
