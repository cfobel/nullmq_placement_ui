class Placement
    constructor: (block_positions=null) ->
        @layers = []
        @block_positions = []
        if block_positions?
            @set_block_positions(block_positions)

    set_block_positions: (block_positions) =>
        @block_positions = block_positions
        dims =
            x: d3.max(p[0] for p in block_positions) + 1
            y: d3.max(p[1] for p in block_positions) + 1
            z: d3.max(p[2] for p in block_positions) + 1

        @layers = []
        for z in [0..dims.z - 1]
            m = Matrix.Zero(dims.x, dims.y)
            # Initialize all block IDs to -1
            m = m.map((v) -> v - 1)
            @layers.push(m)

        for p, i in block_positions
            @set(i, p[0], p[1], p[2])
        return @

    set: (value, x, y, z=0) -> @layers[z].elements[x][y] = value

    e: (x, y, z=0) ->
        return @layers[z].e(x + 1, y + 1)


class PlacementManagerProxy extends EchoJsonController
    constructor: (@context, @req_uri) ->
        super @context, @req_uri

    get_result: (command_dict, on_recv) ->
        @do_request(command_dict, (response) ->
            if 'error' of response
                throw '[error] ' + response['error']
            on_recv(response.result)
        )

    get_placement_keys: (on_recv) =>
        @get_result({command: "get_placement_keys"}, on_recv)

    get_block_positions: (on_recv, outer_i, inner_i=0) ->
        @get_result({command: "get_placement", args: [outer_i, inner_i]}, on_recv)

    get_placement: (on_recv, outer_i, inner_i=0) =>
        _on_recv = (block_positions) ->
            placement = new Placement(block_positions)
            on_recv(placement)
        @get_block_positions(_on_recv, outer_i, inner_i)

    get_swap_context_keys: (on_recv) =>
        @get_result({command: "get_swap_context_keys"}, on_recv)

    get_swap_context: (on_recv, outer_i, inner_i=0) ->
        @get_result({command: "get_swap_context", args: [outer_i, inner_i]}, on_recv)


@Placement =   Placement
@PlacementManagerProxy =  PlacementManagerProxy
