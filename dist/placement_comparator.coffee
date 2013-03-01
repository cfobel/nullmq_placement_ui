class PlacementComparator
    constructor: (grid_a_container, grid_b_container) ->
        @grid_containers = 
            a: grid_a_container
            b: grid_b_container
        @grid_containers.a.style("border", "solid #9e6ab8")
        @grid_containers.b.style("border", "solid #7bb33d")

        @grid_container_ids = {}
        for label, container of @grid_containers
            @grid_container_ids[label] = container.attr("id")

        @opposite_labels =
            a: 'b'
            b: 'a'

        @grids =
            a: null
            b: null

    compare: () =>
        if not @grids.a? or not @grids.b?
            # We must have two grids to do a comparison
            throw '[warning] We must have two grids to do a comparison'
        else if @grids.a.block_positions.length != @grids.b.block_positions.length
            throw '[warning] The grids must have same number of blocks.'
        same = {}
        different = {}
        for data,i in _.zip(@grids.a.block_positions, @grids.b.block_positions)
            [a, b] = ([v.x, v.y, v.z] for v in data)
            if not coffee_helpers.json_compare(a, b)
                different[i] = {a: a, b: b}
            else
                same[i] = a
        return same: same, different: different

    _get_block_rects: (grid, block_ids) =>
        return ((new Block(block_id).rect(grid)[0][0]) for block_id in block_ids)

    select_blocks_by_id: (block_ids, grid=null) =>
        _update = (orig, g) =>
            orig.concat(@_get_block_rects(g, block_ids))

        block_rects = []
        if grid?
            # If grid was specified, only selected matching blocks from that
            # grid.
            block_rects = @_get_block_rects(grid, block_ids)
        else
            # If no grid was specified, select matching blocks from any grid
            # available.
            if @grids.a?
                block_rects = _update(block_rects, @grids.a)
            if @grids.b?
                block_rects = _update(block_rects, @grids.b)
        # Return d3 selection
        d3.selectAll(block_rects)

    reset_grid_a: (place_context) =>
        @grid_containers.a.html('')
        @grids.a = new ControllerPlacementGrid(place_context, @grid_containers.a.attr("id"))
        @_connect_grid_signals(@grids.a)
        if @grids.b?
            @grids.b.set_zoom([0, 0], 1, false)

    reset_grid_b: (place_context) =>
        @grid_containers.b.html('')
        @grids.b = new ControllerPlacementGrid(place_context, @grid_containers.b.attr("id"))
        @_connect_grid_signals(@grids.b)
        if @grids.a?
            @grids.a.set_zoom([0, 0], 1, false)

    set_block_positions: (grid, block_positions) ->
        grid.set_raw_block_positions(block_positions)

    set_block_positions_grid_a: (block_positions) =>
        @set_block_positions(@grids.a, block_positions)
        @highlight_comparison()
        @update_selected()

    set_block_positions_grid_b: (block_positions) =>
        @set_block_positions(@grids.b, block_positions)
        @highlight_comparison()
        @update_selected()

    _connect_grid_signals: (grid) =>
        $(grid).on("block_mouseover", (e) =>
            @select_blocks_by_id([e.block.id]).classed('hovered', true)
            if @grids.a? then @grids.a.update_header(e.block)
            if @grids.b? then @grids.b.update_header(e.block)
        )
        $(grid).on("block_mouseout", (e) =>
            @select_blocks_by_id([e.block.id]).classed('hovered', false)
        )
        $(grid).on("block_click", (e) =>
            @select_blocks_by_id([e.block.id]).classed('selected', (d) ->
                d.selected = e.d.selected
                d.selected
            )
        )
        $(grid).on("zoom_updated", (e) =>
            # When zoom is updated on grid a, update grid b to match.
            # N.B. We must set `signal=false`, since otherwise we would end up
            # in an endless ping-pong back-and-forth between the two grids.
            opposite_grids = {}
            opposite_grids[@grid_container_ids.a] = @grids.b
            opposite_grids[@grid_container_ids.b] = @grids.a
            if opposite_grids[grid.id]?
                opposite_grids[grid.id].set_zoom(e.translate, e.scale, false)
        )

    block_emphasize: (grid, block) =>
        if not grid?
            return
        block.rect(grid).style("fill-opacity", 1.0)
        grid.update_header(block)

    block_deemphasize: (grid, block) =>
        if not grid?
            return
        block.rect(grid).style("fill-opacity", (d) -> d.fill_opacity)
            .style("stroke-width", (d) -> d.stroke_width)

    block_toggle_select: (grid, e) =>
        if not grid?
            return
        # Toggle selected state of clicked block
        if grid.selected(e.block_id)
            grid.deselect_block(e.d)
        else
            grid.select_block(e.d)

    update_selected: () =>
        ids = if @grids.a? then @grids.a.selected_block_ids() else []
        ids = ids.concat(if @grids.b? then @grids.b.selected_block_ids() else [])
        @select_blocks_by_id(ids).classed('selected', true)

    # UI update
    highlight_comparison: () =>
        try
            c = @compare()
            @select_blocks_by_id(Object.keys(c.different))
                .classed('different', true)
                .classed('same', false)
            @select_blocks_by_id(Object.keys(c.same))
                .classed('same', true)
                .classed('different', false)
        catch e
            (->)


@PlacementComparator = PlacementComparator
