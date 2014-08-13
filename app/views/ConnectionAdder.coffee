define ['jquery', 'underscore', 'backbone', 'd3', 'cs!models/ConnectionModel'],
  ($, _, Backbone, d3, ConnectionModel) ->
    class ConnectionAdder extends Backbone.View
      el: $ '#graph'

      events:
        'click .node-connect': 'createDragLine'

      initialize: ->
        that = this
        @graphView = @attributes.graphView

        @drag_line = @graphView.workspace.append('svg:line')
                      .attr('class', 'dragline hidden')
                      .attr("marker-end", "url(#draghead)")
                      .datum(x:0, y:0)
        @creatingConnection = false

        @graphView.svg.on "mousemove", () ->
          mouseX = (d3.mouse(this)[0]-that.graphView.zoom.translate()[0])*1/that.graphView.zoom.scale()
          mouseY = (d3.mouse(this)[1]-that.graphView.zoom.translate()[1])*1/that.graphView.zoom.scale()
          that.drag_line.attr('x2', mouseX).attr('y2', mouseY)

        @creatingConnection = false
        @model.on "node:clicked", (node) =>
          if @creatingConnection
            @makeConnection node
            @creatingConnection = !@creatingConnection

      makeConnection: (node) =>
        @drag_line.classed('hidden', true)
        if node != @drag_line.datum()
          connection = new ConnectionModel
            source: @drag_line.datum().get('_id')
            target: node.get('_id')
            _docId: @model.documentModel.get('_id')
          $.when(connection.save()).then =>
            newConn = @model.putConnection connection
            @model.select newConn
            @model.newConnectionCreated newConn

      createDragLine: (e) ->
        connectId = parseInt $(e.currentTarget).attr("data-id")
        node = @model.nodes.findWhere {_id:connectId}
        @drag_line.classed('hidden', false)
          .datum(node)
          .attr("x1", (d) => node.x)
          .attr("y1", (d) => node.y)
        @creatingConnection = !@creatingConnection

      tick: =>
        that = this
        @drag_line
          .attr("x1", (d) => d.x)
          .attr("y1", (d) => d.y)
