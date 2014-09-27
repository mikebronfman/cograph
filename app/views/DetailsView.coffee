define ['jquery', 'underscore', 'backbone', 'backbone-forms', 'list', 'backbone-forms-bootstrap', 'bootstrap', 'bb-modal',
 'text!templates/details_box.html', 'text!templates/edit_form.html', 'cs!models/NodeModel', 'cs!models/ConnectionModel',
 'bootstrap-color', 'atwho', 'twittertext', 'linkify'],
  ($, _, Backbone, bbf, list, bbfb, Bootstrap, bbModal, detailsTemplate, editFormTemplate, NodeModel, ConnectionModel, ColorPicker, atwho, linkify) ->
    class DetailsView extends Backbone.View
      el: $ 'body'

      events:
        'click .close' : 'closeDetail'
        'click #edit-node-button': 'editNodeConnection'
        'click #edit-connection-button': 'editNodeConnection'
        'submit #edit-node-form': 'saveNodeConnection'
        'click #archive-node-button': 'archiveObj'
        'click #archive-connection-button': 'archiveObj'
        'click #delete-button': 'deleteObj'
        'click #archive-button': 'archiveObj'
        'click #expand-node-button': 'expandNode'

      initialize: ->
        @graphView = @attributes.graphView

        @model.on 'conn:clicked', @openDetails, this
        @model.on 'node:dblclicked', @openDetails, this
        @model.on 'create:connection', @openAndEditConnection, this
        @model.on 'edit:conn', @openDetails, this

        @setupAtWho()

      openDetails: (nodeConnection) ->
        @currentNC = nodeConnection
        workspaceSpokes = @model.getSpokes nodeConnection
        @updateColor @model.defaultColors[nodeConnection.get('color')]
        nodeConnection.on "change:color", (nc) => @updateColor @model.defaultColors[nodeConnection.get('color')]

        @detailsModal = new Backbone.BootstrapModal(
          content: _.template(detailsTemplate, {node:nodeConnection, spokes:workspaceSpokes})
          animate: false
          showFooter: false
        ).open()
        @editNodeConnection()

      updateColor: (color) ->
        $('#details-container .panel-heading').css 'background', color

      closeDetail: () ->
        @graphView.trigger "node:mouseout"

      openAndEditConnection: (conn) ->
        @currentNC = conn
        @openDetails conn
        @editNodeConnection()

      editNodeConnection: ->
        nodeConnection = @currentNC
        @nodeConnectionForm = new Backbone.Form(
          model: nodeConnection
          template: _.template(editFormTemplate)
        ).on('name:blur url:blur tags:blur', (form, editor) ->
          form.fields[editor.key].validate()
        ).render()

        $('#details-container .panel-body').empty().append(@nodeConnectionForm.el)
        $('#details-container input[name=name]', @el).focus()

        isNode = nodeConnection.constructor.name is 'NodeModel'
        colorOptions = colors:[(val for color, val of @model.defaultColors when !((color is 'grey') and isNode))]
        $('.colorpalette').colorPalette(colorOptions).on 'selectColor', (e) =>
          colorValue = e.color
          nodeConnection.set 'color', _.invert(@model.defaultColors)[colorValue]
          nodeConnection.save()

      saveNodeConnection: (e) ->
        e.preventDefault()
        @nodeConnectionForm.commit()
        @nodeConnectionForm.model.save()

        if @nodeConnectionForm.model.constructor.name is "NodeModel"
          newConns = _.uniq @mentionedConns, (conn) ->
            conn.get 'target'

          for c in newConns
            c.save()
            @model.putConnection c

        @closeDetail()
        false

      archiveObj: ->
        if @currentNC.constructor.name is "NodeModel"
          @model.removeNode @currentNC
        else if @currentNC.constructor.name is "ConnectionModel"
          @model.removeConnection @currentNC
        @closeDetail()

      deleteObj: ->
        if @currentNC.constructor.name is "NodeModel"
          @model.deleteNode @currentNC
        else if @currentNC.constructor.name is "ConnectionModel"
          @model.deleteConnection @currentNC
        @closeDetail()

      expandNode: ->
        @currentNC.getNeighbors (neighbors) =>
          for node in neighbors
            newNode = new NodeModel node
            if @model.putNode newNode #this checks to see if the node has passed the filter
              newNode.getConnections @model.nodes, (connections) =>
                @model.putConnection new ConnectionModel conn for conn in connections

      setupAtWho: ->
        that = this
        @mentionedConns = [] # this stores newly mentioned conns

        Backbone.Form.editors.AtWhoEditor = Backbone.Form.editors.TextArea.extend
          render: () ->
            # Call the parent's render method
            Backbone.Form.editors.TextArea.prototype.render.call this
            # Then make the editor's element have atwho.
            this.$el.atwho
              at: "+"
              data: _.filter that.model.nodes.pluck('name'), (name) => name isnt @model.get('name')
              target: ".modal-content"
            .atwho
              at: "#"
              data: that.model.filterModel.getTags('node')
              target: ".modal-content"

            # store inserted mentions
            @mentions = []
            this.$el.on "inserted.atwho", (event, item) =>
              insertedText = item.attr 'data-value'
              if insertedText[0] is "+"
                addedMention = that.model.nodes.findWhere({name:insertedText.slice(1)})
                @mentions.push addedMention
            return this

          # This parses the text to pull out mentions
          getValue: () ->
            str = this.$el.val()
            @model.set "tags", twttr.txt.extractHashtags(str)

            # only include mentions that still remain in the
            # description text
            @mentions = _.filter @mentions, (m) -> str.indexOf(m.get('name')) > 0

            # Create connections to mentioned nodes
            for targetNode in @mentions when targetNode.get('_id') isnt @model.get('_id')
              # get existing connections
              spokes = that.model.connections.filter (c) =>
                c.get('source') is @model.get('_id')
              neighbors = spokes.map (c) -> that.model.getTargetOf(c).get('name')

              # create a connection only if there is not already one
              if targetNode? and !(_.contains neighbors, name)
                connection = new ConnectionModel
                    source: @model.get('_id')
                    target: targetNode.get('_id')
                    _docId: that.model.documentModel.get('_id')
                    description: str

                that.mentionedConns.push connection

            this.$el.val()
