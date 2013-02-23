class PlacementComparator
    constructor: (@grid_a_container, @grid_b_container) ->
        @grid_a_container.html('')
        @grid_a = new PlacementGrid(@grid_a_container.attr("id"))
        @grid_a_container.style("border", "solid #9e6ab8")

        @grid_b_container.html('')
        @grid_b = new PlacementGrid(@grid_b_container.attr("id"))
        @grid_b_container.style("border", "solid #7bb33d")

        obj = @

        $(obj.grid_a).on("block_mouseover", @block_emphasize)
        $(obj.grid_a).on("block_mouseout", @block_deemphasize)
        $(obj.grid_a).on("block_click", @block_toggle_select)
        $(obj.grid_a).on("zoom_updated", (e) ->
            # When zoom is updated on grid a, update grid b to match.
            # N.B. We must set `signal=false`, since otherwise we would end up
            # in an endless ping-pong back-and-forth between the two grids.
            obj.grid_b.set_zoom(e.translate, e.scale, false)
        )

        $(obj.grid_b).on("block_mouseover", @block_emphasize)
        $(obj.grid_b).on("block_mouseout", @block_deemphasize)
        $(obj.grid_b).on("block_click", @block_toggle_select)
        $(obj.grid_b).on("zoom_updated", (e) ->
            # When zoom is updated on grid b, update grid a to match.
            # N.B. We must set `signal=false`, since otherwise we would end up
            # in an endless ping-pong back-and-forth between the two grids.
            obj.grid_a.set_zoom(e.translate, e.scale, false)
        )

    block_emphasize: (e) -> e.block.rect().style("fill-opacity", 1.0)

    block_deemphasize: (e) ->
        e.block.rect().style("fill-opacity", (d) -> d.fill_opacity)
            .style("stroke-width", (d) -> d.stroke_width)

    block_toggle_select: (e) ->
        # Toggle selected state of clicked block
        if e.grid.selected(e.block_id)
            e.grid.deselect_block(e.d)
        else
            e.grid.select_block(e.d)


@PlacementComparator = PlacementComparator
