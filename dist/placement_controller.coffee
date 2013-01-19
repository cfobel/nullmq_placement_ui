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
        @swap_context_detail_template_text =
                d3.select("#swap_context_detail_template").html()
        @swap_context_detail_template =
                _.template(@swap_context_detail_template_text)

    decrement_swap_context_i: () =>
        @swap_context_i -= 1
        @on_swap_context_changed()

    increment_swap_context_i: () =>
        @swap_context_i += 1
        @on_swap_context_changed()

    on_swap_context_changed: () =>
        current_info = d3.select("#id_swap_context_current")
            .html(@swap_context_i)
        d3.selectAll(".swap_context_row").attr("class", "swap_context_row")
        id_text = "#id_swap_context_row_" + @swap_context_i
        test = d3.selectAll(id_text).attr("class", "swap_context_row alert alert-info")

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
    _previous_swap_context: null
    _iterate_continue: (on_recv) ->
        if @_iterate_i < @_iterate_count - 1
            @do_request({"command": "iter.next"}, (value) =>
                @_iterate_i += 1
                @_iterate_continue(on_recv))
        else
            @do_request({"command": "iter.next"}, on_recv)

    extract_data: (d, i) =>
        index: i
        accepted_count: d.accepted_count()
        skipped_count: d.skipped_count()
        total_count: d.total_count()
        participated_count: d.participated_count()
        swap_contexts_count: @swap_contexts.length
        reverse_index: @swap_contexts.length - i - 1
        _sorted_keys: () ->
            ["index", "accepted_count", "skipped_count", "total_count"]

    update_swap_context_info: () =>
        # Update table where each row shows a summary of a swap context, along
        # with a button to display detailed information about the corresponding
        # `SwapContext`.  A `select` button is also included in each row to
        # change the GUI state to reflect the corresponding swap context state
        # (before applying the swaps from the context).
        obj = @
        reverse_swap_contexts = (@extract_data(c, i) for c, i in @swap_contexts)
        @_last_debug_save = reverse_swap_contexts

        info_list = d3.select("#swap_context_list")
            .selectAll(".swap_context_row")
                .data(reverse_swap_contexts, (d) -> d.reverse_index)
        info_list.exit().remove()
        info_list.enter()
                .append("tr")
                    .attr("class", "swap_context_row")

        info_list = d3.select("#swap_context_list")
            .selectAll(".swap_context_row")
                .attr("id", (d, i) ->
                    id_text = "id_swap_context_row_" + d.index
                    console.log("append new row with id:", d, d.index, d.reverse_index, id_text)
                    return id_text
                )
                .html((d, i) =>
                    console.log("swap_context_row", d, i, d.index)
                    @swap_context_template(d)
                )
                .each((d, i) ->
                    d3.select("#id_swap_context_select_" + d.index).on("click", () ->
                        obj.goto(d.index)
                    )
                )

        detailed_info = d3.select("#swap_context_list")
                .selectAll(".swap_context_info_detail")
                    .data(reverse_swap_contexts)
        detailed_info.exit().remove()
        detailed_info.enter()
                .append("div")
                    .attr("class", "swap_context_info_detail")

        detailed_infos = d3.selectAll(".swap_context_info_detail")
            .html((d, i) =>
                @swap_context_detail_template(d)
            )
            # Add a details table for each swap context to the corresponding
            # modal element.
            .each((d, i) ->
                # Allow each modal element to be dragged by its header
                $("#myModal_" + d.index).draggable({
                    handle: ".modal-header"
                })
                id = "#id_swap_context_tbody_" + d.index
                tbody = d3.select(id)
                if "_sorted_keys" of d
                    # The data object, `d`, includes the attribute
                    # `_sorted_keys`, only include the key/value pairs for the
                    # included keys in the details table.
                    keys = d._sorted_keys()
                else
                    # The data object, `d`, does not include the attribute
                    # `_sorted_keys`, so include all key/value pairs from `d`
                    # in the details table for keys that do not start with `_`.
                    keys = Object.keys(d)

                for k in keys
                    try
                        if k[0] == "_"
                            continue
                    catch e
                        # nop
                    v = d[k]
                    row = tbody.append("tr")
                    row.append("th")
                        .html(k)
                    row.append("td")
                        .attr("id", "id_swap_context_" + d.index + "_" + k)
                        .html(v)
            )

    current_swap_context: () ->
        if @swap_context_i > @swap_contexts.length - 1
            error = 
                message: "There are currently no swap contexts"
                code: -100
            throw error
        current_swap_context = @swap_contexts[@swap_context_i]

        @_previous_swap_context = current_swap_context
        return current_swap_context

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
                @decrement_swap_context_i()
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
            @on_swap_context_changed()
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
                @update_swap_context_info()
                @on_swap_context_changed()
                @iterate_action = @iterate_actions.APPLY_SWAPS
            ), iter_count)
        else if @iterate_action == @iterate_actions.REQUEST_SWAPS
            # The next `SwapContext` is already completed and cached, so simply
            # update state.
            @increment_swap_context_i()
            @apply_swap_links()
            @iterate_action = @iterate_actions.APPLY_SWAPS
        else
            @apply_swap_results()
            @iterate_action = @iterate_actions.REQUEST_SWAPS
            c = @current_swap_context()
            if c.accepted_count() <= 0
                @next(iter_count)

    do_request: (message, on_recv) =>
        _on_recv = (response) =>
            #if ("error" of response) and response.error != null
            if not ("result" of response) or ("error" of response) and
                    response.error != null
                error = new Error(response.error)
                @_last_error = error
                throw error
            on_recv(response)
        super message, _on_recv

@PlacementController = PlacementController
