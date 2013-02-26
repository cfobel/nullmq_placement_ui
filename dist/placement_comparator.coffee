class PlacementComparator
    constructor: (@grid_a_container, @grid_b_container) ->
        @grid_a_container.style("border", "solid #9e6ab8")
        @grid_b_container.style("border", "solid #7bb33d")

        @grid_a_container_id = @grid_a_container.attr("id")
        @grid_b_container_id = @grid_b_container.attr("id")
        @opposite_grids = {}

    compare: () =>
        if not @grid_a? or not @grid_b?
            # We must have two grids to do a comparison
            console.log('[warning] We must have two grids to do a comparison')
            return {}
        else if not @grid_a.block_positions.length == @grid_b.block_positions.length
            console.log('[warning] The grids must have same number of blocks.')
            return {}
        same = {}
        different = {}
        for data,i in _.zip(@grid_a.block_positions, @grid_b.block_positions)
            [a, b] = ([v.x, v.y, v.z] for v in data)
            if _.difference(a, b).length > 0
                different[i] = {a: a, b: b}
            else
                same[i] = a
        return same: same, different: different

    reset_grid_a: (place_context) =>
        @grid_a_container.html('')
        @place_context_a = place_context
        @grid_a = new PlacementGrid(@grid_a_container.attr("id"))
        @_connect_grid_signals(@grid_a)
        if @grid_b?
            @grid_b.set_zoom([0, 0], 1, false)

    reset_grid_b: (place_context) =>
        @grid_b_container.html('')
        @place_context_b = place_context
        @grid_b = new PlacementGrid(@grid_b_container.attr("id"))
        @_connect_grid_signals(@grid_b)
        if @grid_a?
            @grid_a.set_zoom([0, 0], 1, false)

    _connect_grid_signals: (grid) =>
        $(grid).on("block_mouseover", (e) =>
            @block_emphasize(@grid_a, e.block)
            @block_emphasize(@grid_b, e.block)
        )
        $(grid).on("block_mouseout", (e) =>
            @block_deemphasize(@grid_a, e.block)
            @block_deemphasize(@grid_b, e.block)
        )
        $(grid).on("block_click", (e) =>
            @block_toggle_select(@grid_a, e)
            @block_toggle_select(@grid_b, e)
        )
        $(grid).on("zoom_updated", (e) =>
            # When zoom is updated on grid a, update grid b to match.
            # N.B. We must set `signal=false`, since otherwise we would end up
            # in an endless ping-pong back-and-forth between the two grids.
            @opposite_grids[@grid_a_container_id] = @grid_b
            @opposite_grids[@grid_b_container_id] = @grid_a
            @opposite_grids[grid.id].set_zoom(e.translate, e.scale, false)
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


@PlacementComparator = PlacementComparator
