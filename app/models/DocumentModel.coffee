define ['backbone', 'b-iobind', 'b-iosync', 'socket-io'], (Backbone, iobind, iosync, io) ->
  class DocumentModel extends Backbone.Model
    urlRoot: '/document'
    idAttribute: '_id'
    noIoBind: false
    socket: io.connect('')

    defaults:
      name: 'Untitled'
      _id: -1
      workspaces: []
      publicView: 0 # 0: only owner, 1: link only, 2: anyone
      publicEdit: 0 # 0: only owner, 1: link only, 2: anyone
      createdBy: ''
      description: ''

    initialize: ->
      @socket.on @urlRoot+":update", (objData) =>
        @set objData

      @socket.on "/workspace:update", (data) =>
        currentWorkspaces = @get 'workspaces'
        # only add to the list if it isn't already there
        if not _.contains _.pluck(currentWorkspaces, '_.id'), data._id
          currentWorkspaces.push {_id:data._id, name:data.name}

      @socket.on "/workspace:delete", (data) =>
        currentWorkspaces = @get 'workspaces'
        this.set "workspaces", _.filter(currentWorkspaces, (x) -> return parseInt(x._id) != parseInt(data._id))

    isNew: ->
      @get(@idAttribute) < 0

    serialize: ->
      name:@get('name')
      _id:@get('_id')
      publicView: @get('publicView')
      publicEdit: @get('publicEdit')
      createdBy: @get('createdBy')
      description: @get('description')

    sync: (method, model, options) ->
      options = options || {}
      options.data = @serialize()
      # if created by a logged in user, then include that information
      if method is 'create'
        currUser = window.user
        options.data.createdBy = if currUser? then currUser.name else ''

      options.contentType = 'application/json'
      Backbone.sync.apply(this, [method, model, options])

    # Getter methods
    getNodeNames: (cb) ->
      $.get @url() + '/nodes/names', {}, (names) =>
        cb names

    getTagNames: (cb) ->
      $.get @url() + '/tags', {}, (tagNames) =>
        cb tagNames

    getNodeByName: (name, cb) ->
      $.get @url() + '/getNodeByName', {name: name}, (node) =>
        cb node

    getConnsByName: (name, cb) ->
      $.get @url() + '/getConnsByName', {name: name}, (conns) =>
        cb conns

    getNodesByTag: (tag, cb) ->
      $.get @url() + '/getNodesByTag', {tag: tag}, (nodes) =>
        cb nodes

    getAnalytics: (cb) ->
      $.get @url() + '/analytics', {}, (results) ->
        cb results
