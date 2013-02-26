class PlacementComparator
    constructor: (@grid_a_container, @grid_b_container) ->
        @grid_a_container.html('')
        @grid_a = new PlacementGrid(@grid_a_container.attr("id"))
        @grid_a_container.style("border", "solid #9e6ab8")

        @grid_b_container.html('')
        @grid_b = new PlacementGrid(@grid_b_container.attr("id"))
        @grid_b_container.style("border", "solid #7bb33d")

        obj = @

        for grid in [@grid_a, @grid_b]
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
        $(obj.grid_a).on("zoom_updated", (e) ->
            # When zoom is updated on grid a, update grid b to match.
            # N.B. We must set `signal=false`, since otherwise we would end up
            # in an endless ping-pong back-and-forth between the two grids.
            obj.grid_b.set_zoom(e.translate, e.scale, false)
        )

        $(obj.grid_b).on("zoom_updated", (e) ->
            # When zoom is updated on grid b, update grid a to match.
            # N.B. We must set `signal=false`, since otherwise we would end up
            # in an endless ping-pong back-and-forth between the two grids.
            obj.grid_a.set_zoom(e.translate, e.scale, false)
        )

    block_emphasize: (grid, block) =>
        block.rect(grid).style("fill-opacity", 1.0)
        grid.update_header(block)

    block_deemphasize: (grid, block) =>
        block.rect(grid).style("fill-opacity", (d) -> d.fill_opacity)
            .style("stroke-width", (d) -> d.stroke_width)

    block_toggle_select: (grid, e) =>
        # Toggle selected state of clicked block
        if grid.selected(e.block_id)
            grid.deselect_block(e.d)
        else
            grid.select_block(e.d)


@PlacementComparator = PlacementComparator
