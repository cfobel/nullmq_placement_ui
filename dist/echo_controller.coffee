class EchoController
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


class EchoJsonController extends EchoController
    serialize: (javascript_obj) -> JSON.stringify(javascript_obj)

    deserialize: (json_string) ->
        try
            value = JSON.parse(json_string)
        catch error
            alert(error)
            value = null
        return value


class PlacementController extends EchoJsonController
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

    swap_context: () ->
            all: new Array()
            participated: {},
            not_participated: {},
            accepted: {},
            skipped: {},
            by_from_block_id: {},
            by_to_block_id: {},
            block_positions: @placement_grid.block_positions

    unhighlight_block: (block) =>
        block_rect_id = "#id_block_" + block.block_id
        block_rect = d3.select(block_rect_id)
        if not (block_rect == null)
            block_rect.style("fill-opacity", block.fill_opacity)
                        .style("stroke-width", block.stroke_width)

    highlight_block: (block) =>
        block_rect_id = "#id_block_" + block.block_id
        block_rect = d3.select(block_rect_id)
        if not (block_rect == null)
            block_rect.style("fill-opacity", 1.0).style("stroke-width", 6)

    highlight_block_swaps: (block_id) =>
        @apply_to_block_swaps(block_id, @highlight_block)

    unhighlight_block_swaps: (block_id) =>
        @apply_to_block_swaps(block_id, @unhighlight_block)

    apply_to_block_swaps: (block_id, callback) =>
        # Apply the callback function to each block involved in any swap where
        # either the `from` or `to` block ID is `block_id`.
        for block in @connected_blocks(block_id)
            callback(block)

    connected_blocks: (block_id) =>
        try
            c = this.current_swap_context()
        catch e
            if e.code and e.code == -100
                return []
            else
                throw e

        # Highlight block under cursor
        connected_blocks = [@placement_grid.block_positions[block_id]]
        if block_id of c.by_from_block_id
            # Highlight any blocks that involve the current block as the `from`
            # block id
            for swap_info in c.by_from_block_id[block_id]
                block = @placement_grid.block_positions[swap_info.swap_config.ids.to]
                connected_blocks.push(block)
        else if block_id of c.by_to_block_id
            # Highlight any blocks that involve the current block as the `to`
            # block id
            for swap_info in c.by_to_block_id[block_id]
                block = @placement_grid.block_positions[swap_info.swap_config.ids.from_]
                connected_blocks.push(block)
        return connected_blocks

    block_mouseover: (d, i, from_rect) =>
        @highlight_block_swaps(i)

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
        @unhighlight_block_swaps(i, from_rect)

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
                if swap_info.swap_config.ids.from_ of swap_context.by_from_block_id
                    block_swap_infos = swap_context.by_from_block_id[swap_info.swap_config.ids.from_]
                    block_swap_infos.push(swap_info)
                else
                    block_swap_infos = [swap_info]
                    swap_context.by_from_block_id[swap_info.swap_config.ids.from_] = block_swap_infos
            if swap_info.swap_config.ids.to >= 0
                if swap_info.swap_config.ids.to of swap_context.by_to_block_id
                    block_swap_infos = swap_context.by_to_block_id[swap_info.swap_config.ids.to]
                    block_swap_infos.push(swap_info)
                else
                    block_swap_infos = [swap_info]
                    swap_context.by_to_block_id[swap_info.swap_config.ids.to] = block_swap_infos
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
        @swap_contexts.push(@swap_context())
        @_iterate_continue(on_recv)

    iterate_and_update: (iter_count) =>
        update_grid = (value) =>
            try
                swap_context = @current_swap_context()
                console.log(["swap_context", swap_context])
                @placement_grid.set_swap_links(swap_context)
                # Make a copy of the current block positions and update the new
                # copy to reflect the new positions of blocks involved in accepted
                # swaps.
                block_positions = $.extend(true, [], @placement_grid.block_positions)
                for swap_i,swap_info of swap_context.accepted
                    from_d = block_positions[swap_info.swap_config.ids.from_]
                    [from_d.x, from_d.y] = swap_info.swap_config.coords.to
                    to_d = block_positions[swap_info.swap_config.ids.to]
                    [to_d.x, to_d.y] = swap_info.swap_config.coords.from_
                    console.log(["accepted swap", from_d, to_d])
                raw_block_positions = []
                for d in block_positions
                    raw_block_positions.push([d.x, d.y, d.z])
                for block, i in block_positions
                    old_d = @placement_grid.block_positions[i]
                    new_array = raw_block_positions[i]
                    if old_d.x != new_array[0] or old_d.y != new_array[1] or old_d.z != new_array[2]
                        console.log(["new block position", i, old_d, new_array])
                do_task = () => @placement_grid.set_raw_block_positions(raw_block_positions)
                setTimeout(do_task, 250)
            catch error
                # There is no current swap context, so do nothing
                swap_context = null
        @iterate_swap_eval(update_grid, iter_count)

@EchoController = EchoController
@EchoJsonController = EchoJsonController
@PlacementController = PlacementController
