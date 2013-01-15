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
        @iterate_actions = 
            REQUEST_SWAPS: 10
            APPLY_SWAPS:   20
        @iterate_action = @iterate_actions.REQUEST_SWAPS
        @swap_context_i = -1
        _.templateSettings =
          interpolate: /\{\{(.+?)\}\}/g
        @swap_context_template_text = d3.select("#swap_context_template").html()
        @swap_context_template = _.template(@swap_context_template_text)

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
        try
            c = this.current_swap_context()
        catch e
            if e.code and e.code == -100
                return []
            else
                throw e

        # Apply the callback function to each block involved in any swap where
        # either the `from` or `to` block ID is `block_id`.
        for block in c.connected_blocks(block_id)
            callback(block)

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

    update_swap_context_info: () =>
        # Update current block info table
        current_info = d3.select("#swap_context_current")
                .selectAll(".swap_context_info")
                .data(@swap_contexts)
        current_info.enter()
                .append("div")
                .attr("class", "swap_context_info")
        current_info.exit().remove()
        current_info.html((d, i) =>
                    data =
                        index: i
                        accepted_count: d.accepted_count()
                    @swap_context_template(data)
                )

    current_swap_context: () ->
        if @swap_contexts.length < 0
            error = 
                message: "There are currently no swap contexts"
                code: -100
            throw error
        @update_swap_context_info()
        return @swap_contexts[@swap_context_i]

    process_swap: (message) =>
        swap_context = @current_swap_context()
        swap_info = @deserialize(message)
        swap_context.process_swap(swap_info)

    iterate_swap_eval: (on_recv, count) ->
        if count == undefined
            count = 1
        @_iterate_count = count
        @_iterate_i = 0
        @_iterate_continue(on_recv)

    undo_swaps: () =>
        if @iterate_action = @iterate_actions.REQUEST_SWAPS
            swap_context = @current_swap_context()
            @placement_grid.set_block_positions(swap_context.block_positions)
            @iterate_action = @iterate_actions.APPLY_SWAPS

    load_placement: (load_config=false) ->
        obj = @
        @do_request({"command": "get_block_positions"}, (value) =>
            @placement_grid.set_raw_block_positions(value.result)
            if load_config
                @load_config()
            @iterate_action = @iterate_actions.REQUEST_SWAPS
        )

    load_config: () =>
        @do_request({"command": "config"}, (response) =>
                config = response.result
                for a, i in config.area_ranges
                    a = new AreaRange(a[0], a[1], a[2], a[3])
                    @placement_grid.highlight_area_range(a)
        )

    apply_swap_results: () =>
        if @iterate_action == @iterate_actions.APPLY_SWAPS
            swap_context = @current_swap_context()
            try
                block_positions = swap_context.apply_swaps()
            catch e
                @load_placement()
                return
            moved_count = 0
            for block, i in block_positions
                old_d = @placement_grid.block_positions[i]
                new_d = block_positions[i]
                if old_d.x != new_d.x or old_d.y != new_d.y or old_d.z != new_d.z
                    moved_count += 1
            @placement_grid.set_block_positions(block_positions)
            @iterate_action = @iterate_actions.REQUEST_SWAPS
            return moved_count
        else
            error = 
                message: "Cannot apply swaps current state"
                code: -200
            throw error

    apply_swap_links: () =>
        try
            swap_context = @current_swap_context()
            swap_context.set_swap_link_data(@placement_grid)
            swap_context.update_link_formats(@placement_grid)
            @iterate_action = @iterate_actions.APPLY_SWAPS
        catch error
            # There is no current swap context, so do nothing
            swap_context = null

    iterate_and_update: (iter_count=1) =>
    previous: () =>
        if @swap_context_i > 0
            c = @current_swap_context()
            if @iterate_action == @iterate_actions.APPLY_SWAPS
                @swap_context_i -= 1
                c = @current_swap_context()
                @apply_swap_links()
                @iterate_action = @iterate_actions.REQUEST_SWAPS
                if c.accepted_count() <= 0
                    @previous()
            else
                @undo_swaps()

    goto: (swap_context_i) =>
        if swap_context_i >= 0
            @swap_context_i = swap_context_i
            @apply_swap_links()
            @apply_swap_results()
            @iterate_action = @iterate_actions.REQUEST_SWAPS
            @undo_swaps()

    home: () => @goto(0)

    end: () =>
        if @swap_contexts.length >= 0
           @goto(@swap_contexts.length - 1)

    next: (iter_count=1, append=true) =>
        if @swap_context_i >= 0
            c = @current_swap_context()
        if append and @iterate_action == @iterate_actions.REQUEST_SWAPS and
                (@swap_context_i < 0 or
                        @swap_context_i == @swap_contexts.length - 1)
            if @swap_context_i >= 0 and c.all.length <= 0
                # The current swap context does not have any swaps assigned to
                # it, so reuse it rather than creating a new one.
                null
            else
                # There is no `next` stored `SwapContext` available, so iterate to
                # create a new one.
                @swap_contexts.push(new SwapContext(@placement_grid.block_positions))
            @swap_context_i = @swap_contexts.length - 1
            @iterate_swap_eval((() =>
                @apply_swap_links()
                @iterate_action = @iterate_actions.APPLY_SWAPS
            ), iter_count)
        else if @iterate_action == @iterate_actions.REQUEST_SWAPS
            # The next `SwapContext` is already completed and cached, so simply
            # update state.
            @swap_context_i += 1
            @apply_swap_links()
            @iterate_action = @iterate_actions.APPLY_SWAPS
        else
            @apply_swap_results()
            @iterate_action = @iterate_actions.REQUEST_SWAPS
            c = @current_swap_context()
            if c.accepted_count() <= 0
                @next(iter_count)


@EchoController = EchoController
@EchoJsonController = EchoJsonController
@PlacementController = PlacementController
