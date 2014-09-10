define ['jquery', 'underscore', 'backbone', 'cs!models/WorkspaceModel', 'cs!models/NodeModel',
'atwho', 'twittertext', 'elastic'],
  ($, _, Backbone, WorkspaceModel, NodeModel, atwho, twittertext) ->
    class AddNodeView extends Backbone.View
      el: $ '#add-node-form'

      events: 
        'submit' : 'addNode'

      initialize: ->
        @descriptionArea = $('#add-description')
        @titleArea = $('#add-title')
        @colorArea = $('#add-color')
        @imageArea = $('#add-image')
        @colorInput = $('#add-color-container')
        @imageInput = $('#add-image-container')

        @descriptionArea.elastic()
        @titleArea.elastic()
        @addColorPopoverShown = false
        @addImagePopoverShown = false 

        _.each(@model.defaultColors, (i, color) =>
          @colorInput.append('<div class="add-color-item" style="background-color:'+i+'" data-color="'+color+'"></div>')
        )

        $('.add-color-item').on 'click', (e) =>
          @colorArea.css('color', $(e.currentTarget).css('background-color'))
          @colorArea.data('color', $(e.currentTarget).data('color'))
          @colorInput.addClass('hidden')

        @colorArea.on 'click', (e) =>
          @imageInput.addClass('hidden')
          @colorInput.toggleClass('hidden')

        @imageArea.on 'click', (e) =>
          @colorInput.addClass('hidden')
          @imageInput.toggleClass('hidden')

        @titleArea.on 'keydown', (e) =>
          if(e.keyCode == 13)
            e.preventDefault()
            @descriptionArea.focus()          

        @descriptionArea.on 'focus', (e) =>
          if($('#add').hasClass('contracted'))
            $('#add').removeClass('contracted')
            @descriptionArea.attr('rows', '1')
                  
        $('body').on 'click', (e) =>
          @resetAdd()

        $('#add').on 'click', (e) =>
          e.stopPropagation()

        @colorArea.on 'hover', (e) =>
          $('#add-color-popover').show()

        @descriptionArea.on 'shown.atwho', (e) =>
          @showingAtWho = true
        @descriptionArea.on 'hidden.atwho', (e) =>
          @showingAtWho = false

        @descriptionArea.atwho
          at: "@"
          data: @model.nodes.pluck('name')
          target: "#add-node-form"
        .atwho
          at: "#"
          data: @model.filterModel.getTags('node')
          target: "#add-node-form"
        
      resetAdd: () ->
        @imageInput.addClass('hidden')
        @colorInput.addClass('hidden')
        
        @descriptionArea.atwho 'destroy'
        $('div[id=atwho-container]').remove()
        @titleArea.val('')
        @descriptionArea.val('') 
        @descriptionArea.trigger('change')
        @titleArea.trigger('change')   
        $('#add').addClass('contracted')  
                
      addNode: (e) ->
        if e? then e.preventDefault()

        attributes = {_docId: @model.nodes._docId}
        _.each $('#add-node-form').serializeArray(), (obj) ->
          attributes[obj.name] = obj.value

        attributes.selected = true
        console.log(@colorArea.css('color'))
        attributes.color = @colorArea.data('color')
        attributes.image = @imageInput.val()
        if(attributes['name'] == "" && attributes['description'] != "")
          attributes['name'] = attributes['description'].substring(0,25)+ "..."

        node = new NodeModel attributes
        if node.isValid()
          @model.putNode node
          node.set "tags", twttr.txt.extractHashtags attributes.description

          $.when(node.save()).then =>
            # Create connections to mentioned nodes
            names = twttr.txt.extractMentions attributes.description

            for name in _.uniq names
              targetNode = @model.nodes.findWhere {name:name}
              if targetNode?
                connection = new @model.connections.model
                    source: node.get('_id')
                    target: targetNode.get('_id')
                    _docId: @model.documentModel.get('_id')
                    description: node.get('description')
                connection.save()
                @model.putConnection connection

          @$el[0].reset() # blanks out the form fields
          @descriptionFocus = false
          @resetAdd()
        else
          $('input', @el).attr('placeholder', node.validate())
       

