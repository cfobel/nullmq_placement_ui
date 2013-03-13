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

        # Add inline forms to allow initialization of a manager from a URI.
        for label in ['a', 'b']
            @manager_selectors[label] = @containers[label]
                .datum(label: label, uri: 'tcp://maeby.fobel.net:12346')
              .insert('div', '.grid_' + label)
                .attr('class', (d) -> 'grid_' + d.label + '_manager_selector')
                .html((d) => @templates.manager_selector(d))
              .select('button')
                .on('click', (d) -> 
                    d.uri = $(this.parentElement).find('input').val()
                    d.manager = new PlacementManagerProxy(obj.zmq_context, d.uri)
                    obj['reset_grid_' + d.label](d.manager)
                )

    reset_grid_a: (placement_manager) =>
        @grid_containers.a.html('')
        @grids.a = new PlacementManagerGrid(placement_manager, @grid_containers.a)
        @_connect_grid_signals(@grids.a)
        if @grids.b?
            @grids.b.set_zoom([0, 0], 1, false)

    reset_grid_b: (placement_manager) =>
        @grid_containers.b.html('')
        @grids.b = new PlacementManagerGrid(placement_manager, @grid_containers.b)
        @_connect_grid_signals(@grids.b)
        if @grids.a?
            @grids.a.set_zoom([0, 0], 1, false)

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
