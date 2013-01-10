class @EchoController
    constructor: (@context, @uri) ->
        @echo_fe = @context.socket(nullmq.REQ)
        @echo_fe.connect(@uri)
        @last_response = null

    send: (message) -> @echo_fe.send(message)

    serialize: (message) -> message

    deserialize: (message) -> message

    do_request: (message, on_recv) ->
        try
            @send(@serialize(message))
            obj = @
            _on_recv = (value) ->
                value = obj.deserialize(value)
                on_recv(value)
            @echo_fe.recv(_on_recv)
        catch error
            alert(error)


class @EchoJsonController extends @EchoController
    serialize: (javascript_obj) -> JSON.stringify(javascript_obj)

    deserialize: (json_string) ->
        try
            value = JSON.parse(json_string)
        catch error
            alert(error)
            value = null
        return value


class @PlacementController extends @EchoJsonController
    get_swap_context: () -> {
            'all': new Array()
            'participated': {},
            'not_participated': {},
            'accepted': {},
            'skipped': {},
            'by_from_block_id': {},
            'by_to_block_id': {},
        }
    block_mouseover: (d, i, from_rect) =>
        try
            c = this.current_swap_context()
        catch e
            if e.code and e.code == -100
                return
            else
                throw e
        if `i in c.by_from_block_id`
            swap_info = c.by_from_block_id[i]
            @to_rect = d3.select("#id_block_" + swap_info.swap_config.ids.to)
        else if `i in c.by_to_block_id`
            swap_info = c.by_to_block_id[i]
            block_id = "#id_block_" + swap_info.swap_config.ids.from_
            @to_rect = d3.select(block_id)
        if not (@to_rect == null)
            console.log("to_rect is something")
            # This block was involved in the last set of swaps
            @_last_data =
                block_id: i
                from_d: d
                from_rect: from_rect
                swap_info: swap_info
            console.log(@_last_data)
            @to_rect.style("fill-opacity", 1.0).style("stroke-width", 6)
        from_rect.style("fill-opacity", 1.0).style("stroke-width", 6)
        # Update current block info table
        current_info = d3.select("#placement_info_current")
                .selectAll(".placement_info")
                .data([d], (d) -> d.block_id)
        current_info.enter()
                .append("div")
                .attr("class", "placement_info")
                .html((d) -> placement_grid.template(d))
        current_info.exit().remove()
    block_mouseout: (d, i, from_rect) =>
        from_rect.style("fill-opacity", d.fill_opacity)
            .style("stroke-width", d.stroke_width)
        if not (@to_rect == null)
            @to_rect.style("fill-opacity", d.fill_opacity)
                        .style("stroke-width", d.stroke_width)
            @to_rect = null
    constructor: (@placement_grid, @context, @action_uri, @swap_uri) ->
        @swap_contexts = new Array()
        super @context, @action_uri
        @swap_fe = @context.socket(nullmq.SUB)
        @swap_fe.connect(@swap_uri)
        @swap_fe.setsockopt(nullmq.SUBSCRIBE, "")
        @swap_fe.recvall(@process_swap)
        @initialized = false
        @placement_grid.block_mouseover = @block_mouseover
        @placement_grid.block_mouseout = @block_mouseout
        @to_rect = null
    initialize: (callback) ->
        if not @initialized
            console.log("initialize")
            @do_request({"command": "initialize", "kwargs": {"depth": 2}}, callback)
            @initialized = true
    _iterate_count: 1
    _iterate_i: 0
    _iterate_continue: (on_recv) ->
        if @_iterate_i < @_iterate_count - 1
            @do_request({"command": "iter.next"}, (value) =>
                @_iterate_i += 1
                @_iterate_continue(on_recv))
        else
            @do_request({"command": "iter.next"}, on_recv)
    current_swap_context: () ->
        if @swap_contexts <= 0
            error = 
                message: "There are currently no swap contexts"
                code: -100
            throw error
        return @swap_contexts[@swap_contexts.length - 1]
    process_swap: (message) =>
        swap_context = @current_swap_context()
        swap_info = @deserialize(message)
        swap_context.all.push(swap_info)
        if swap_info.swap_config.participate
            if swap_info.swap_config.ids.from_ >= 0
                swap_context.by_from_block_id[swap_info.swap_config.ids.from_] = swap_info
            if swap_info.swap_config.ids.to >= 0
                swap_context.by_to_block_id[swap_info.swap_config.ids.to] = swap_info
            swap_context.participated[swap_info.swap_i] = swap_info
            if swap_info.swap_result.swap_accepted
                swap_context.accepted[swap_info.swap_i] = swap_info
            else
                swap_context.skipped[swap_info.swap_i] = swap_info
        else
            swap_context.not_participated[swap_info.swap_i] = swap_info
    iterate_swap_eval: (on_recv, count) ->
        if count == undefined
            count = 1
        @_iterate_count = count
        @_iterate_i = 0
        @swap_contexts.push(@get_swap_context())
        @_iterate_continue(on_recv)
