class Net
    constructor: (@grid, @net_id, @block_ids) ->
        @dom_id = "id_net_" + @net_id
        @grid.grid.append("g").attr("id", @dom_id)

    element: () -> d3.selectAll("#" + @dom_id)

    block_coords: ->
        coords = []
        for b in @block_ids
            p = @grid.block_positions[b]
            coords.push(x: p.x, y: p.y)
        coords
    center_of_gravity: ->
        x_sum = 0
        y_sum = 0
        coords = @block_coords()
        for c in coords
            x_sum += c.x
            y_sum += c.y
        x: x_sum / coords.length, y: y_sum / coords.length
    highlight_blocks: () ->
        for b in @block_ids
            d3.select("#id_block_" + b)
                .style("stroke-width", "5px")
                .style("opacity", 0.8)
    unhighlight_blocks: () ->
        for b in @block_ids
            d3.select("#id_block_" + b)
                .style("stroke-width", "1px")
                .style("opacity", 0.2)
    unhighlight: () =>
        cog = @element().selectAll(".center_of_gravity")
        links = @element().selectAll(".net_link").remove()
        console.log("unhighlight", cog, links, @)
        cog.remove()
        links.remove()
        @unhighlight_blocks()
    highlight: () ->
        @highlight_blocks()
        @draw_links()
        cog = @grid.cell_center(@center_of_gravity())
        @element().append("circle")
            .attr("class", "center_of_gravity")
            .attr("data-net_id", @net_id)
            .attr("cx", cog.x)
            .attr("cy", cog.y)
            .attr("r", 8)
            .style("fill", "steelblue")
    draw_links: ->
        root_coords = @grid.cell_center(@center_of_gravity())
        target_coords = _.map(@block_coords(), @grid.cell_center)
        net_links = @element().selectAll(".net_link")
          .data(target_coords, (d, i) -> [root_coords, d])
        net_links.enter()
          .append("line")
            .attr("class", "net_link")
            .attr("pointer-events", "none")
        net_links.exit().remove()
        net_links.attr("x1", root_coords.x)
            .attr("y1", root_coords.y)
            .attr("x2", (d) -> d.x)
            .attr("y2", (d) -> d.y)
            .style("stroke", "black")
            .style("stroke-opacity", 0.7)


class ModifierController extends EchoJsonController
    constructor: (@placement_grid, @context, @action_uri, @swap_uri) ->
        @placement_i = -1
        @placement_manager = new PlacementManager()

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
        @swap_template_text = d3.select("#swap_template").html()
        @swap_template = _.template(@swap_template_text)
        @swap_delta_template_text = d3.select("#id_swap_delta_template").html()
        @swap_delta_template = _.template(@swap_delta_template_text)
        @swap_context_template_text = d3.select("#swap_context_template").html()
        @swap_context_template = _.template(@swap_context_template_text)
        @swap_context_detail_template_text =
                d3.select("#swap_context_detail_template").html()
        @swap_context_detail_template =
                _.template(@swap_context_detail_template_text)

        obj = @
        $(obj).on("initialized", (e) -> obj.load_placement(true))

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
        block_ids = @placement_grid.selected_block_ids()
        @update_net_link_formats(block_ids)

    select_link_elements_by_block_ids: (block_ids, only_master=true, accepted=true, skipped=true, non_participate=true) =>
        swap_ids = @swap_ids_for_block_ids(block_ids, only_master, accepted, skipped, non_participate)
        if swap_ids.length > 0
            link_element_ids = ("#id_swap_link_" + i for i in swap_ids)
            return @placement_grid.grid.selectAll(link_element_ids.join(","))
        else
            return d3.select()

    swap_ids_for_block_ids: (block_ids, only_master=true, accepted=true, skipped=true, non_participate=true) =>
        swap_ids_dict = {}
        for block_id in block_ids
            swap_ids = @swap_ids_for_block_id(block_id, only_master, accepted, skipped, non_participate)
            for swap_id in swap_ids
                if swap_id of swap_ids_dict
                    swap_ids_dict[swap_id] += 1
                else
                    swap_ids_dict[swap_id] = 1
        swap_ids = (k for k,v of swap_ids_dict)
        return swap_ids

    swap_ids_for_block_id: (block_id, only_master=true, accepted=true, skipped=true, non_participate=true) =>
        c = @current_swap_context()
        swaps = []
        for s in c.all when s.swap_config.ids.from_ == block_id or s.swap_config.ids.to == block_id
            [p, a] = [s.swap_config.participate, s.swap_result.swap_accepted]
            if not s.swap_config.master > 0 and only_master
                continue
            if a and accepted
               swaps.push(s)
            else if not a and p and skipped
               swaps.push(s)
            else if non_participate and not p
               swaps.push(s)
        return (s.swap_i for s in swaps)

    connected_block_ids: (block_id) =>
        connected_block_ids = []
        net_ids = @block_to_net_ids[block_id]
        for i in [0..@block_net_counts[block_id] - 1]
            net_id = net_ids[i]
            for b in @net_to_block_ids[net_id]
                if b != block_id
                    connected_block_ids.push(b)
        return _.sortBy(_.uniq(connected_block_ids), (v) -> v) #, (name: i for i in [0..10])]

    connected_block_ids_by_root_block_ids: (block_ids) =>
        (root: b,  connected_block_ids: @connected_block_ids(b) for b in block_ids)

    nets_by_block_id: (block_ids) ->
        nets = {}
        for b in block_ids
            nets[b] = (@net_by_id(n) for n in @block_to_net_ids[b] when n >= 0)
        nets

    map_nets_by_block_id: (block_ids, f) ->
        nets_by_block_id = @nets_by_block_id(block_ids)
        results = []
        for b, nets of nets_by_block_id
            results.push(_.map(nets, f))
        results

    net_by_id: (net_id) =>
        block_ids = @net_to_block_ids[net_id]
        return new Net(@placement_grid, net_id, block_ids)

    select_block_elements_by_ids: (block_ids) =>
        if block_ids.length > 0
            block_element_ids = (".block_" + i for i in block_ids)
            return @placement_grid.grid.selectAll(block_element_ids.join(","))
        else
            # Empty selection
            return d3.select()

    highlight_block_swaps: (block_ids) =>
        if @swap_context_i >= 0 and block_ids.length
            c = @current_swap_context()
            connected_block_ids = c.deep_connected_block_ids(block_ids, false)
            @placement_grid.grid.selectAll(".block")
              .filter((d) -> not (d.block_id in block_ids) and not (d.block_id in connected_block_ids))
              .style("opacity", 0.2)
              #console.log("highlight_block_swaps", block_ids, connected_block_ids)
            @select_block_elements_by_ids(block_ids)
                .style("opacity", 1.0)
                .style("fill-opacity", 1.0)
                .style("stroke-width", 3)
            @select_block_elements_by_ids(connected_block_ids)
                .style("opacity", 0.65)
                .style("fill-opacity", 1.0)
                .style("stroke-width", 3)
            @placement_grid.grid.selectAll(".link")
                .style("opacity", 0.1)
            @select_link_elements_by_block_ids(block_ids)
                .style("stroke-width", 2)
                .style("opacity", 1)

    unhighlight_block_swaps: (block_ids) =>
        #console.log("unhighlight_block_swaps", block_ids)
        if @swap_context_i >= 0
            c = @current_swap_context()
            c.update_block_formats(@placement_grid)
            c.update_link_formats(@placement_grid)
            block_ids = @placement_grid.selected_block_ids()
            if block_ids.length
                @highlight_block_swaps(block_ids)

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
        block_ids = @placement_grid.selected_block_ids()
        if @swap_context_i >= 0
            c = @current_swap_context()
            @highlight_block_swaps(block_ids.concat([i]))
            @update_swap_list_info(block_ids.concat([i]))

        @update_net_link_formats(block_ids.concat([i]))

        obj = @
        # Update current block info table
        current_info = d3.select("#placement_info_current")
                .selectAll(".placement_info")
                .data([d], (d) -> d.block_id)
        current_info.enter()
                .append("div")
                .attr("class", "placement_info")
                .html((d) ->
                    net_ids = (b for b in obj.block_to_net_ids[i] when b >= 0)
                    value = $().extend({net_ids: net_ids}, d)
                    placement_grid.template(value)
                )
        current_info.exit().remove()

    update_net_link_formats: (block_ids) =>
        obj = @
        connected_block_ids = @connected_block_ids_by_root_block_ids(block_ids)
        net_link_groups = @placement_grid.grid.selectAll(".net_link_group").data(
            connected_block_ids, (d) ->
                b = obj.placement_grid.block_positions[d.root]
                coords = x: b.x, y: b.y
                coords
        )

        net_link_groups.enter()
          .append("g")
            .attr("class", "net_link_group")
        net_link_groups.exit().remove()

        net_link_groups.each((d) ->
            root_coords = obj.placement_grid.cell_center(
                    obj.placement_grid.block_positions[d.root])
            target_coords = []
            for b in d.connected_block_ids
                target_coords.push(obj.placement_grid.cell_center(
                        obj.placement_grid.block_positions[b]))
            net_links = d3.select(this).selectAll(".net_link")
              .data(target_coords, (d, i) -> [root_coords, d])
            net_links.enter()
              .append("line")
                .attr("class", "net_link")
                .attr("pointer-events", "none")
            net_links.exit().remove()
            net_links.attr("x1", root_coords.x)
                .attr("y1", root_coords.y)
                .attr("x2", (d) -> d.x)
                .attr("y2", (d) -> d.y)
                .style("stroke", "black")
                .style("stroke-opacity", 0.1)
        )

    block_mouseout: (d, i, from_rect) =>
        @unhighlight_block_swaps(i, from_rect)
        block_ids = @placement_grid.selected_block_ids()
        @update_swap_list_info(block_ids)
        @update_net_link_formats(block_ids)

    initialize: (callback) ->
        obj = @
        if not @initialized
            @do_request({"command": "initialize", "kwargs": {"depth": 2}}, () ->
                obj.do_request({"command": "net_to_block_id_list"}, (value) ->
                    obj.net_to_block_ids = value.result
                    obj.do_request({"command": "block_to_net_ids"}, (value) ->
                        obj.block_to_net_ids = value.result
                        obj.do_request({"command": "block_net_counts"}, (value) ->
                            obj.block_net_counts = value.result
                            $(obj).trigger(type: "initialized", controller: obj)
                            obj.initialized = true
                        )
                    )
                )
            )

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

    update_swap_list_info: (block_ids) =>
        obj = @
        c = @current_swap_context()
        swap_links = @select_link_elements_by_block_ids(block_ids, false)
        if swap_links.empty()
            data = []
        else
            data = swap_links.data()
        swap_rows = d3.select("#id_swap_tbody")
            .selectAll(".swap_row")
                .data(data, (d) -> d.swap_i)
        swap_rows.exit().remove()
        swap_rows.enter()
                .append("tr")
                    .attr("class", "swap_row")
                    .attr("id", (d, i) ->
                        id_text = "id_swap_row_" + d.swap_i
                        return id_text
                    )
                    .html((d, i) =>
                        @swap_template(d)
                    )
                    .each((d, i) =>
                        try
                            popover_options =
                                html: true
                                title: 'Swap ' + d.swap_i + ' <button type="button" class="close" data-dismiss="clickover">&times;</button>'
                                global_close: false
                                esc_close: false
                                allow_multiple: true
                                placement: 'bottom'
                            if d.swap_config.participate
                                cost_details = d.swap_result.delta_cost_details
                                result =
                                    from_: @delta_cost_matrix(cost_details.from_)
                                    to: @delta_cost_matrix(cost_details.to)
                                table_data =
                                    from_:
                                        matrix: result.from_.delta_cost_matrix
                                        totals: result.from_.totals
                                    to:
                                        matrix: result.to.delta_cost_matrix
                                        totals: result.to.totals
                                from_d = $().extend({prefix: "from"}, d)
                                to_d = $().extend({prefix: "to"}, d)
                                content =
                                    # Only add tables to content if we have
                                    # valid matrix for the corresponding set of
                                    # delta costs.  If there is no delta cost
                                    # matrix, `table_data.*.matrix` will be set
                                    # to `null`, so we check for that here.
                                    from_: if table_data.from_.matrix? then @swap_delta_template(from_d) else ''
                                    to: if table_data.to.matrix? then @swap_delta_template(to_d) else ''
                                @_last_data = table_data: table_data, content: content
                                popover_options.content = content.from_ + content.to
                                popover_options.onShown = () ->
                                    from_tbody = $("#id_swap_row_actions_" + d.swap_i + " > .popover table .from_delta")
                                    to_tbody = $("#id_swap_row_actions_" + d.swap_i + " > .popover table .to_delta")
                                    obj._last_tbody_tags = [from_tbody, to_tbody]
                                    obj._last_table_data = table_data

                                    fill_table = (data, totals, table) ->
                                        tbody = d3.select(table).select("tbody")
                                        delta_column_ids = 4: 'sum_x', 7: 'sum_y', 10: 'squared_sum_x', 13: 'squared_sum_y', 14: 'total'
                                        for i in [0..data.dimensions().rows - 1]
                                            # Append row for each net connected to block
                                            row = tbody.append("tr").attr("class", "net_delta_row")
                                            row_data = data.elements[i]
                                            for r, k in row_data
                                                cell = row.append("td")
                                                    .html(r)
                                                console.log(k, (k of delta_column_ids))
                                                if (k of delta_column_ids)
                                                    if r < 0
                                                        cell.attr("class", "improving")
                                                    else if r > 0
                                                        cell.attr("class", "non_improving")
                                            obj._test = [delta_column_ids, (4 of delta_column_ids)]
                                        # Append footer row
                                        row = tbody.append("tr").attr("class", "net_delta_row")
                                        row.append("th").attr("colspan", 4).html("Total")
                                        cell = row.append("th").html(totals.sum_x_d)
                                        if totals.sum_x_d < 0
                                            cell.attr("class", "improving")
                                        else if r > 0
                                            cell.attr("class", "non_improving")
                                        row.append("th").attr("colspan", 2).html("&nbsp;")
                                        cell = row.append("th").html(totals.sum_y_d)
                                        if totals.sum_y_d < 0
                                            cell.attr("class", "improving")
                                        else if r > 0
                                            cell.attr("class", "non_improving")
                                        row.append("th").attr("colspan", 2).html("&nbsp;")
                                        cell = row.append("th").html(totals.squared_sum_x_d)
                                        if totals.squared_sum_x_d < 0
                                            cell.attr("class", "improving")
                                        else if r > 0
                                            cell.attr("class", "non_improving")
                                        row.append("th").attr("colspan", 2).html("&nbsp;")
                                        cell = row.append("th").html(totals.squared_sum_y_d)
                                        if totals.squared_sum_y_d < 0
                                            cell.attr("class", "improving")
                                        else if r > 0
                                            cell.attr("class", "non_improving")
                                        cell = row.append("th").html(totals.total_d)
                                        if totals.total_d < 0
                                            cell.attr("class", "improving")
                                        else if r > 0
                                            cell.attr("class", "non_improving")

                                    width = -1

                                    if table_data.from_.matrix?
                                        # Only fill "from_" table if we have a
                                        # valid delta costs matrix
                                        data = table_data.from_.matrix
                                        totals = table_data.from_.totals
                                        from_table = from_tbody.parent()[0]
                                        fill_table(data, totals, from_table)
                                        width = $(from_table).width()

                                    if table_data.to.matrix?
                                        # Only fill "to" table if we have a
                                        # valid delta costs matrix
                                        data = table_data.to.matrix
                                        totals = table_data.to.totals
                                        to_table = to_tbody.parent()[0]
                                        fill_table(data, totals, to_table)
                                        width = Math.max(width, $(to_table).width())
                                    $(this.$tip).width(width + 35)
                                    # Allow the popover to be repositioned by
                                    # clicking and dragging.
                                    $(this.$tip).draggable()
                                    $(".popover-content", this.$tip).addClass("alert")
                                    if d.swap_result.swap_accepted
                                        $(".popover-content", this.$tip).addClass("alert-success")
                            else
                                popover_options.content = "Swap was not evaluated"
                                popover_options.onShown = () ->
                                    $(this.$tip).draggable()
                                    $(".popover-content", this.$tip)
                                        .addClass("alert")
                                        .addClass("alert-error")
                            $("#id_swap_show_delta_cost_" + d.swap_i).clickover(popover_options)
                        catch e
                            @_last_error = e
                            console.log("error generating summary for swap", d, popover_options)
                    )

    delta_cost_matrix: (cost_details) =>
        net_count = cost_details.net_block_counts.length
        if net_count <= 0
            result = delta_cost_matrix: null, totals: null
            return result
        data = Matrix.Zero(net_count, 15)
        for i in [0..cost_details.net_block_counts.length - 1]
            [net_id, block_count] = cost_details.net_block_counts[i]
            old = cost_details.old_sums
            new_= cost_details.new_sums
            sum =
                x:
                    old: old[i][0]
                    new_: new_[i][0]
                    d: new_[i][0] - old[i][0]
                y:
                    old: old[i][1]
                    new_: new_[i][1]
                    d: new_[i][1] - old[i][1]
            old = cost_details.old_squared_sums
            new_= cost_details.new_squared_sums
            squared_sum =
                x:
                    old: old[i][0]
                    new_: new_[i][0]
                    d: new_[i][0] - old[i][0]
                y:
                    old: old[i][1]
                    new_: new_[i][1]
                    d: new_[i][1] - old[i][1]
            k = 0
            data.elements[i][k++] = net_id
            data.elements[i][k++] = block_count
            data.elements[i][k++] = sum.x.old
            data.elements[i][k++] = sum.x.new_
            data.elements[i][k++] = sum.x.d
            data.elements[i][k++] = sum.y.old
            data.elements[i][k++] = sum.y.new_
            data.elements[i][k++] = sum.y.d
            data.elements[i][k++] = squared_sum.x.old
            data.elements[i][k++] = squared_sum.x.new_
            data.elements[i][k++] = squared_sum.x.d
            data.elements[i][k++] = squared_sum.y.old
            data.elements[i][k++] = squared_sum.y.new_
            data.elements[i][k++] = squared_sum.y.d
        total_costs = data.col(5)
            .add(data.col(8))
            .add(data.col(11))
            .add(data.col(14))
        for i in [0..data.dimensions().rows - 1]
            data.elements[i][14] = total_costs.elements[i]
        _sum = (d) -> _.reduce(d, ((a, b) -> a + b), 0)
        totals =
            sum_x_d: _sum(data.col(5).elements)
            sum_y_d: _sum(data.col(8).elements)
            squared_sum_x_d: _sum(data.col(11).elements)
            squared_sum_y_d: _sum(data.col(14).elements)
            total_d: _sum(data.col(15).elements)
        return delta_cost_matrix: data, totals: totals

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
                    return id_text
                )
                .html((d, i) =>
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
        swap_message = @deserialize(message)
        if swap_message.type == 'swaps_start'
            # Create a new swap context
            @_swap_context = new SwapContext()
        else if swap_message.type == 'swap_info'
            swap_context = @current_swap_context()
            swap_context.process_swap(swap_message)
            @_swap_context.process_swap(swap_message)
        else if swap_message.type == 'swaps_end'
            # We've reached the end of this round of swaps.  We can now
            # add the completed swap context to the `placement_manager`
            @placement_manager.append_swap_context(@_swap_context)
        else
            console.log(swap_message, "[process_swap] unknown message type: " + swap_message.type)

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
            block_ids = @placement_grid.selected_block_ids()
            @update_net_link_formats(block_ids)
            @iterate_action = @iterate_actions.APPLY_SWAPS

    translate_block_positions: (block_positions) ->
        data = new Array()
        for position, i in block_positions
            item =
                block_id: i
                x: position[0]
                y: position[1]
                z: position[2]
            data.push(item)
        return data

    load_placement: (load_config=false) ->
        obj = @
        @do_request({"command": "get_block_positions"}, (value) =>
            @placement_grid.set_raw_block_positions(value.result)
            if load_config
                @load_config()
            @iterate_action = @iterate_actions.REQUEST_SWAPS

            options =
                block_positions: @translate_block_positions(value.result)
                net_to_block_ids: obj.net_to_block_ids
                block_to_net_ids: obj.block_to_net_ids
                block_net_counts: obj.block_net_counts
            placement = new Placement(options)
            $(obj).trigger(type: "placement_loaded", placement: placement)
            obj.placement_manager.append_placement(placement)
            if obj.placement_i < 0
                # There is no placement currently selected, so automatically
                # select the new placement.
                obj.placement_i = 0
                $(obj).trigger(type: "placement_focus_set", placement_i: obj.placement_i, placement: placement)
        )

    get_placement: ->
        @placement_manager.placements[@placement_i]

    load_config: () =>
        obj = @
        @do_request({"command": "config"}, (response) =>
            config = response.result
            for a, i in config.area_ranges
                a = new AreaRange(a[0], a[1], a[2], a[3])
                @placement_grid.highlight_area_range(a)
            @do_request({"command": "net_to_block_id_list"}, (value) =>
                obj.net_to_block_ids = value.result
                @do_request({"command": "block_to_net_ids"}, (value) =>
                    obj.block_to_net_ids = value.result
                    @do_request({"command": "block_net_counts"}, (value) =>
                        obj.block_net_counts = value.result
                    )
                )
            )
        )

    apply_swap_results: () =>
        if @iterate_action == @iterate_actions.APPLY_SWAPS
            swap_context = @current_swap_context()
            try
                block_positions = swap_context.apply_swaps()
            catch e
                console.log("error applying swaps", e, e.stack)
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
            block_ids = @placement_grid.selected_block_ids()
            @update_net_link_formats(block_ids)
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
            swap_context.update_block_formats(@placement_grid)
            block_ids = @placement_grid.selected_block_ids()
            @highlight_block_swaps(block_ids)
            @update_net_link_formats(block_ids)
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
        if swap_context_i < @placement_manager.placements.length
            @placement_i = swap_context_i
            placement = @placement_manager.placements[@placement_i]
            $(@).trigger(type: "placement_focus_set", placement_i: @placement_i, placement: placement)

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

@ModifierController = ModifierController
@Net = Net
