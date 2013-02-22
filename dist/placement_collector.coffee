class PlacementCollector
    constructor: (@process_infos) ->
        @_on_recv = null
        @finished = false
        @block_positions = []

    _handle_block_positions: (process_info, block_positions) =>
        data = $().extend(process_info, {block_positions: block_positions})
        @block_positions.push(data)
        if @block_positions.length >= @process_infos.length
            # We've received all requested placements, so call `on_recv`
            if @_on_recv?
                @_on_recv(@block_positions)
                @finished = true

    collect: (on_recv) =>
        @finished = false
        @block_positions = []
        @_on_recv = on_recv
        for info in @process_infos
            info.controller.get_block_positions((value) => @_handle_block_positions(info, value))

@PlacementCollector = PlacementCollector
