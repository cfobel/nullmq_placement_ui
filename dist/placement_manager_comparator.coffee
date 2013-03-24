class PlacementManagerComparator extends BasePlacementComparator
    ###
    # This class requires a `PlacementManagerProxy` to be provided when
    # resetting a grid.  Each `PlacementManagerProxy` provides control and
    # status connections to a remote placement manager.  Additional UI elements
    # can then be used to select from a list of available placements, as well
    # as whether or not to show the swaps.
    ###
    constructor: (@zmq_context, a_container, b_container) ->
        super a_container, b_container
        obj = @
        @manager_selectors = {}
        @placement_managers = {}
        @grid_width = null

        @templates = @get_templates()

        default_uris =
            a: 'tcp://maeby.fobel.net:9999'
            b: 'tcp://localhost:1111'

        # Add inline forms to allow initialization of a manager from a URI.
        for label in ['a', 'b']
            @manager_selectors[label] = @containers[label]
                .datum(label: label, uri: default_uris[label])
              .insert('div', '.grid_' + label)
                .attr('class', (d) -> 'grid_' + d.label + '_manager_selector')
                .html((d) => @templates.manager_selector(d))
              .select('button')
                .on('click', (d) -> 
                    d.uri = $(this.parentElement).find('input').val()
                    d.manager = new PlacementManagerProxy(obj.zmq_context, d.uri)
                    obj.reset_grid(d.label, d.manager)
                )

    get_templates: () ->
        _.templateSettings = interpolate: /\{\{(.+?)\}\}/g
        template_texts =
            manager_selector: d3.select('.placement_manager_grid_selector_template').html()
        templates = {}
        for k, v of template_texts
            templates[k] = _.template(v)
        return templates

    reset_grid_a: (placement_manager) =>
        @reset_grid('a', placement_manager)

    reset_grid_b: (placement_manager) =>
        @reset_grid('b', placement_manager)

    reset_grid: (label, placement_manager) =>
        @grid_containers[label].html('')
        console.log('[reset_grid_' + label + ']', @grid_width)
        @grids[label] = new PlacementManagerGrid(placement_manager, @grid_containers[label], @grid_width)
        if not @grid_width?
            @grid_width = @grids[label].width * 1.15
        @_connect_grid_signals(@grids[label])
        opposite = a: 'b', b: 'a'
        @reset_zoom(opposite[label])

    reset_zoom: (label=null) =>
        if label?
            keys = [label]
        else
            keys = ['a', 'b']
        for k in keys
            if @grids[k]?
                @grids[k].set_zoom([0, 0], 1, false)

    _connect_grid_signals: (grid) =>
        super grid

        # Connect signals for updating net-related hover activity.
        $(grid).on("block_mouseover", (e) =>
            if @grids.a?
                if e.grid == @grids.b
                    e.block.rect(@grids.a)
                        .classed('manager_hovered', true)
            if @grids.b?
                if e.grid == @grids.a
                    e.block.rect(@grids.b)
                        .classed('manager_hovered', true)
        )
        $(grid).on("block_mouseout", (e) =>
            if @grids.b? and e.grid == @grids.a
                e.block.rect(@grids.b)
                    .classed('manager_hovered', false)
            if @grids.a? and e.grid == @grids.b
                e.block.rect(@grids.a)
                    .classed('manager_hovered', false)
        )


@PlacementManagerComparator = PlacementManagerComparator
