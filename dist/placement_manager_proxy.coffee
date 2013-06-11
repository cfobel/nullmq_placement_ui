class Placement
    constructor: (block_positions=null) ->
        @layers = []
        @block_positions = []
        @dims = null
        if block_positions?
            @set_block_positions(block_positions)

    set_block_positions: (block_positions) =>
        @block_positions = block_positions
        @dims =
            x: d3.max(p[0] for p in block_positions) + 1
            y: d3.max(p[1] for p in block_positions) + 1
            z: d3.max(p[2] for p in block_positions) + 1

        @layers = []
        for z in [0..@dims.z - 1]
            m = Matrix.Zero(@dims.x, @dims.y)
            # Initialize all block IDs to -1
            m = m.map((v) -> v - 1)
            @layers.push(m)

        for p, i in block_positions
            @set(i, p[0], p[1], p[2])
        return @

    set: (value, x, y, z=0) => @layers[z].elements[x][y] = value

    e: (x, y, z=0) =>
        return @layers[z].e(x + 1, y + 1)


class PlacementManagerProxy extends RpcProxy
    constructor: (@context, @req_uri, @uuid='placement_manager_proxy', on_init=null) ->
        super @context, @req_uri, @uuid
        @_cache =
            swap_contexts: {}
            placements: {}
            place_configs: {}
        if on_init?
            @wait_for_init(on_init)

    wait_for_init: (on_init) =>
        obj = @
        check_init = () =>
            if not @_initialized
                setTimeout(check_init, 10)
            else
                console.log(@_initialized)
                on_init(obj)
        setTimeout(check_init, 10)

    get_place_config: (on_recv, key) =>
        if @_cache.place_configs[key]?
            # The corresponding swap context is available in our cache
            console.log('[get_place_config]', 'cache available for key: ', key)
            on_recv(@_cache.place_configs[key])
            return
        obj = @
        _on_recv = (config) ->
            obj._cache.place_configs[key] = config
            on_recv(config)
        @_rpc__get_place_config(_on_recv, key)

    get_placement: (on_recv, key) =>
        if @_cache.placements[key]?
            # The corresponding swap context is available in our cache
            console.log('[get_placement]', 'cache available for key: ', key)
            on_recv(@_cache.placements[key])
            return
        obj = @
        _on_recv = (block_positions) ->
            placement = new Placement(block_positions)
            obj._cache.placements[key] = placement
            on_recv(placement)
        @_rpc__get_placement(_on_recv, key, kwargs={json: true})

    get_swap_context: (on_recv, key) =>
        if @_cache.swap_contexts[key]?
            # The corresponding swap context is available in our cache
            console.log('[get_swap_context]', 'cache available for key: ', key)
            on_recv(@_cache.swap_contexts[key])
            return

        @get_placement(((placement) =>
            @get_swap_context_infos(((swap_infos) =>
                swap_context = new SwapContext(placement)
                for s in swap_infos
                    swap_context.process_swap(s)
                @_cache.swap_contexts[key] = swap_context
                on_recv(swap_context)
            ), key, kwargs={json: true})
        ), key)


@Placement =   Placement
@PlacementManagerProxy =  PlacementManagerProxy
