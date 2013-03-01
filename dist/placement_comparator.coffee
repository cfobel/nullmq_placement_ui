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
            throw '[warning] We must have two grids to do a comparison'
        else if @grid_a.block_positions.length != @grid_b.block_positions.length
            throw '[warning] The grids must have same number of blocks.'
        same = {}
        different = {}
        for data,i in _.zip(@grid_a.block_positions, @grid_b.block_positions)
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
            block_rects = _update(block_rects, grid)
        else
            if @grid_a?
                block_rects = _update(block_rects, @grid_a)
            if @grid_b?
                block_rects = _update(block_rects, @grid_b)
        d3.selectAll(block_rects)

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

    set_block_positions: (grid, block_positions) ->
        grid.set_raw_block_positions(block_positions)

    set_block_positions_grid_a: (block_positions) =>
        @set_block_positions(@grid_a, block_positions)
        @highlight_comparison()

    set_block_positions_grid_b: (block_positions) =>
        @set_block_positions(@grid_b, block_positions)
        @highlight_comparison()

    _connect_grid_signals: (grid) =>
        $(grid).on("block_mouseover", (e) =>
            @select_blocks_by_id([e.block.id]).style("fill-opacity", 1.0)
            if @grid_a? then @grid_a.update_header(e.block)
            if @grid_b? then @grid_b.update_header(e.block)
        )
        $(grid).on("block_mouseout", (e) =>
            @select_blocks_by_id([e.block.id])
                .style("fill-opacity", (d) -> d.fill_opacity)
                .style("stroke-width", (d) -> d.stroke_width)
        )
        $(grid).on("block_selected", (e) =>
            rect = e.block.rect(grid)
            e.d.original_fill = rect.style("fill")
            e.block.rect(grid).style("fill", "orange")
        )
        $(grid).on("block_deselected", (e) =>
            e.block.rect(grid).style("fill", e.d.original_fill ? "grey")
        )
        $(grid).on("zoom_updated", (e) =>
            # When zoom is updated on grid a, update grid b to match.
            # N.B. We must set `signal=false`, since otherwise we would end up
            # in an endless ping-pong back-and-forth between the two grids.
            @opposite_grids[@grid_a_container_id] = @grid_b
            @opposite_grids[@grid_b_container_id] = @grid_a
            if @opposite_grids[grid.id]?
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

    # UI update
    highlight_comparison: () =>
        try
            c = @compare()
            @select_blocks_by_id(Object.keys(c.different)).style("fill", "red")
            @select_blocks_by_id(Object.keys(c.same)).style("fill", "limegreen")
        catch e
            (->)

    highlight_selected: () =>
        selected = @grid_a.selected_block_ids()
        if selected.length > 0
            @select_blocks_by_id(selected).style("fill", "orange")


@PlacementComparator = PlacementComparator
