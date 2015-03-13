crypto = require 'crypto'


url = require 'url'

HtmlPreviewView = require './pepper-autocomplete-view'

module.exports =
  htmlPreviewView: null

  activate: (state) ->
    atom.commands.add 'atom-workspace', "pepper-autocomplete:toggle", => @toggle()

    atom.workspace.registerOpener (uriToOpen) ->
      try
        {protocol, host, pathname} = url.parse(uriToOpen)
      catch error
        return
      return unless protocol is 'pepper-autocomplete:'

      try
        pathname = decodeURI(pathname) if pathname
      catch error
        return

      if host is 'editor'
        new HtmlPreviewView(editorId: pathname.substring(1))
      else
        new HtmlPreviewView(filePath: pathname)

    @toggle() if atom.config.get 'pepper-autocomplete.autoToggle'



  toggle: ->
    editor = atom.workspace.getActiveEditor()
    return unless editor?

    uri = "pepper-autocomplete://editor/#{editor.id}"
    previewPane = atom.workspace.paneForUri(uri)
    if previewPane
      previewPane.destroyItem(previewPane.itemForUri(uri))
      return

    previousActivePane = atom.workspace.getActivePane()
    atom.workspace.open(uri, split: 'right', searchAllPanes: true).done (htmlPreviewView) ->
      if htmlPreviewView instanceof HtmlPreviewView
        htmlPreviewView.renderHTML()
        previousActivePane.activate()


  config:
    LicenseKey:
        type: 'string'
        default: ''
        description: 'License key is required to access the service.  Get one at https://pepper-autocomplete.com'

    toggleUserID:
      type: 'boolean'
      default: true
      description: 'Toggles the generation and use of a unique id to get more customized and relevant results.'

    autoToggle:
      type: 'boolean'
      default: true
      description: 'Start when atom editor starts.'
