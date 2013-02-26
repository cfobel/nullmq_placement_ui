class Block
    constructor: (@id) ->
    rect_id: () => "block_" + @id
    rect: (grid) => d3.select("#" + grid.grid_container.attr("id") + " ." + @rect_id())


class Curve
    constructor: (@_source=null, @_target=null, @_translate=null) ->
        if @_translate == null
            @_translate = (coords) -> coords
    translate: (t=null) =>
        if t != null
            @_translate = t
            @
        else
            @_translate
    target: (t=null) =>
        if t != null
            @_target = t
            @
        else
            @_target
    source: (s=null) =>
        if s != null
            @_source = s
            @
        else
            @_source
    d: () =>
        coords =
            source: @translate()(@source())
            target: @translate()(@target())
        if @source().y != @target().y and @source().x != @target().x
            path_text = d3.svg.diagonal()
                .source(coords.source)
                .target(coords.target)()
        else
            # The source and target share the same row or column.  Use an arc
            # to connect them rather than a diagonal.  A diagonal degrades to a
            # straight line in this case, making it difficult to distinguish
            # overlapping links.
            dx = coords.target.x - coords.source.x
            dy = coords.target.y - coords.source.y
            dr = Math.sqrt(dx * dx + dy * dy)
            if @source().y == @target().y and @source().x % 2 == 0
                flip = 1
            else if @source().x == @target().x and @source().y % 2 == 0
                flip = 1
            else
                flip = 0
            path_text = "M" + coords.source.x + "," + coords.source.y + "A" + dr + "," + dr + " 0 0," + flip + " " + coords.target.x + "," + coords.target.y
        return path_text


class SwapContext
    # Each `SwapContext` instance represents a set of swap configurations that
    # were generated.  In addition to storing each set of swaps, the
    # information for each swap is indexed by:
    #   -Whether or not the swap configuration was evaluated
    #   If the swap was evaluated, also index by:
    #       -The `from_` block of the swap configuration.
    #       -The `to` block of the swap configuration.
    #       -Whether or not the swap was accepted/skipped.
    #
    # Organizing swaps into `SwapContext` objects makes it straight-forward to
    # apply the swaps to a starting set of block positions.

    constructor: (block_positions) ->
        # Make a copy of the current block positions, which will be updated to
        # reflect the new positions of blocks involved in accepted swaps.
        @block_positions = $.extend(true, [], block_positions)
        @all = []
        @participated = {}
        @not_participated = {}
        @accepted = {}
        @skipped = {}
        @by_from_block_id = {}
        @by_to_block_id = {}

    compute_delta_cost: (d) ->
        result = @compute_delta_costs(d)
        sum = (d) -> _.reduce(d, ((a, b) -> a + b), 0)
        return sum(result.to_costs.new_) -
                sum(result.to_costs.old) +
            sum(result.from_costs.new_) -
                sum(result.from_costs.old)

    delta_costs_summary: (d) ->
        summary = (costs) ->
            old = $M(costs.old)
            new_ = $M(costs.new_)
            delta = new_.subtract(old)
            new_.flatten().join(" + ") + " - " + old.flatten().join(" - ") +
                " (" + delta.flatten().join(" + ") + ")"
        from_summary = if d.from_costs.old? then summary(d.from_costs) else ""
        to_summary = if d.to_costs.old? then summary(d.to_costs) else ""
        "{" + from_summary + "} + {" + to_summary + "}"
    
    compute_delta_costs: (d) ->
        costs = {}
        for name,details of {'from_': d.from_, 'to': d.to}
            costs[name] = {}
            for k in ["old", "new"]
                try
                    sums = details[k + "_sums"]
                    squared_sums = details[k + "_squared_sums"]
                    if k == "new"
                        k = "new_"
                    if sums.length
                        costs[name][k] = @_compute_costs(sums, squared_sums,
                                     details.net_block_counts)
                    else
                        costs[name][k] = null
                catch e
                    console.log("[compute_delta_costs] ERROR:", name, k, details, e)
        return from_costs: costs['from_'], to_costs: costs['to']

    _compute_costs: (sums, squared_sums, net_block_counts) ->
        x_costs = []
        y_costs = []
        for i in [0..net_block_counts.length - 1]
            result = Math.round(
                sums[i][0] +
                sums[i][1] +
                squared_sums[i][0] +
                squared_sums[i][1] +
                net_block_counts[i][1])
            costs.push(result)
            #return _.reduce(costs, ((a, b) -> a + b), 0);
        return costs

    accepted_count: () => Object.keys(@accepted).length
    skipped_count: () => Object.keys(@skipped).length
    participated_count: () => Object.keys(@participated).length
    total_count: () => @all.length
    process_swap: (swap_info) =>
        # Record information for current swap in `all` array, as well
        # as indexed by:
        #   -Whether or not the swap configuration was evaluated
        #   If the swap was evaluated, also index by:
        #       -The `from_` block of the swap configuration.
        #       -The `to` block of the swap configuration.
        #       -Whether or not the swap was accepted/skipped.
        @all.push(swap_info)
        if swap_info.swap_config.participate
            if swap_info.swap_config.ids.from_ >= 0
                if swap_info.swap_config.ids.from_ of @by_from_block_id
                    block_swap_infos = @by_from_block_id[swap_info.swap_config.ids.from_]
                    block_swap_infos.push(swap_info)
                else
                    block_swap_infos = [swap_info]
                    @by_from_block_id[swap_info.swap_config.ids.from_] = block_swap_infos
            if swap_info.swap_config.ids.to >= 0
                if swap_info.swap_config.ids.to of @by_to_block_id
                    block_swap_infos = @by_to_block_id[swap_info.swap_config.ids.to]
                    block_swap_infos.push(swap_info)
                else
                    block_swap_infos = [swap_info]
                    @by_to_block_id[swap_info.swap_config.ids.to] = block_swap_infos
            @participated[swap_info.swap_i] = swap_info
            if swap_info.swap_result.swap_accepted
                @accepted[swap_info.swap_i] = swap_info
            else
                @skipped[swap_info.swap_i] = swap_info
        else
            @not_participated[swap_info.swap_i] = swap_info

    set_swap_link_data: (placement_grid) ->
        # Create a d3 diagonal between the blocks involved in each swap
        # configuration in the current context.
        swap_links = placement_grid.grid.selectAll(".link").data(@all)
        swap_links.enter()
            .append("svg:path")
            .attr("class", "link")
            .attr("id", (d) -> "id_swap_link_" + d.swap_i)
            .style("fill", "none")
            .style("pointer-events", "none")
            .style("stroke", "none")
            .style("stroke-width", 1.5)
            .style("opacity", 0)
        swap_links.exit().remove()

    from_ids: (swap_dict, only_master=false) ->
        (swap_info.swap_config.ids.from_ for swap_id,swap_info of swap_dict when swap_info.swap_config.ids.from_ >= 0 and (not only_master or swap_info.swap_config.master > 0))
    to_ids: (swap_dict, only_master=false) -> (swap_info.swap_config.ids.to for swap_id,swap_info of swap_dict when swap_info.swap_config.ids.to >= 0 and (not only_master or swap_info.swap_config.master > 0))

    block_element_ids: (block_ids) -> ("#id_block_" + id for id in block_ids)

    accepted_count: () => Object.keys(@accepted).length

    update_block_formats: (placement_grid) ->
        g = placement_grid.grid
        g.selectAll(".block")
            .style("stroke-width", (d) -> if placement_grid.selected(d.block_id) then 2 else 1)
            .style("fill-opacity", (d) -> if placement_grid.selected(d.block_id) then 1.0 else 0.5)

        colorize = (block_ids, fill_color, opacity=null) =>
            if block_ids.length <= 0
                return
            g.selectAll(@block_element_ids(block_ids).join(", "))
                .style("fill", fill_color)
                .style("opacity", opacity ? 1.0)
        colorize(@from_ids(@not_participated), "red", 0.5)
        colorize(@to_ids(@skipped, true), "yellow")
        colorize(@from_ids(@skipped, true), "darkorange")
        colorize(@from_ids(@accepted, true), "darkgreen")
        colorize(@to_ids(@accepted, true), "limegreen")

    update_link_formats: (placement_grid) ->
        # Update the style and end-point locations for each swap link.
        swap_links = placement_grid.grid.selectAll(".link")
        curve = new Curve()
        curve.translate(placement_grid.cell_center)
        swap_links.style("stroke-width", 1)
            .style("opacity", (d) ->
                if not d.swap_config.master and d.swap_config.participate
                    return 0.0
                else if d.swap_result.swap_accepted
                    return 0.9
                else if not d.swap_config.participate
                    return 0.35
                else
                    return 0.8
            )
            .style("stroke", (d) ->
                if d.swap_result.swap_accepted
                    return "green"
                else if not d.swap_config.participate
                    return "red"
                else
                    return "gold"
            )
        swap_links.attr("d", (d) =>
                [from_x, from_y] = d.swap_config.coords.from_
                from_coords = x: from_x, y: from_y
                [from_x, from_y] = d.swap_config.coords.to
                to_coords = x: from_x, y: from_y
                curve.source(from_coords).target(to_coords)
                @_latest_curve = curve
                curve.d()
            )

    apply_swaps: () ->
        block_positions = $.extend(true, [], @block_positions)
        # Update the block positions array based on the accepted swaps in the
        # current context.
        for swap_i,swap_info of @accepted
            if swap_info.swap_config.master > 0
                if swap_info.swap_config.ids.from_ >= 0
                    from_d = block_positions[swap_info.swap_config.ids.from_]
                    [from_d.x, from_d.y] = swap_info.swap_config.coords.to
                if swap_info.swap_config.ids.to >= 0
                    to_d = block_positions[swap_info.swap_config.ids.to]
                    [to_d.x, to_d.y] = swap_info.swap_config.coords.from_
        return block_positions

    connected_block_ids: (block_id) => (b.block_id for b in @connected_blocks(block_id))

    deep_connected_block_ids: (block_ids_input, include_initial=true) =>
        # Store block_ids in dictionary-like object for fast membership test
        block_ids = {} #block_ids_input[..]
        connected_block_ids = block_ids_input[..]
        for block_id in block_ids_input
            block_ids[block_id] = null
            ids = @connected_block_ids(block_id)
            connected_block_ids = connected_block_ids.concat(ids)
        connected_block_ids = _.uniq(connected_block_ids)
        return (+i for i in connected_block_ids when include_initial or not (i of block_ids))

    connected_blocks: (block_id) =>
        # Return list of blocks that are connected to the block with ID
        # `block_id` and that were involved involved in any swaps within the
        # current swap context.
        connected_blocks = [@block_positions[block_id]]
        if block_id of @by_from_block_id
            # Highlight any blocks that involve the current block as the `from`
            # block id
            for swap_info in @by_from_block_id[block_id]
                if swap_info.swap_config.ids.to >= 0
                    block = @block_positions[swap_info.swap_config.ids.to]
                    connected_blocks.push(block)
        else if block_id of @by_to_block_id
            # Highlight any blocks that involve the current block as the `to`
            # block id
            for swap_info in @by_to_block_id[block_id]
                if swap_info.swap_config.ids.to >= 0
                    block = @block_positions[swap_info.swap_config.ids.from_]
                    connected_blocks.push(block)
        return _.uniq(connected_blocks)


class PlacementGrid
    constructor: (@id, @width=null) ->
        @zoom = d3.behavior.zoom()
        @grid_container = d3.select('#' + @id)
        @header = @grid_container.append('div')
                    .attr('class', 'grid_header')
        if not @width?
            obj = @
            jq_obj = $(obj.grid_container[0])
            # Restrict height to fit within viewport
            width = jq_obj.width()
            height = $(window).height() - jq_obj.position().top - 130
            @width = Math.min(width, height)
            #console.log("PlacementGrid", "inferred width", @width)
        @width /= 1.15
        @grid = d3.select("#" + @id)
                    .append("svg")
                        .attr("width", 1.1 * @width)
                        .attr("height", 1.1 * @width)
                    .append('svg:g')
                        .attr("id", @id + "_transform_group")
                        .call(@zoom.on("zoom", () => @update_zoom()))
                    .append('svg:g')
                        .attr("class", "chart")
        zoom = window.location.hash
        result = /#translate\((-?\d+\.\d+),(-?\d+\.\d+)\)\s+scale\((-?\d+\.\d+)\)/.exec(zoom)
        if result and result.length == 4
            [translate_x, translate_y, scale] = result[1..]
            @zoom.scale(scale)
            @zoom.translate([translate_x, translate_y])
            @update_zoom()
        @scale =
            x: d3.scale.linear()
            y: d3.scale.linear()
        @dims =
            x:
                min: 1000000
                max: -1
            y:
                min: 1000000
                max: -1
        @colors = d3.scale.category10().domain(d3.range(10))
        @selected_fill_color_num = 8
        @io_fill_color = @colors(1)
        @clb_fill_color = @colors(9)
        @_selected_blocks = {}
        _.templateSettings =
          interpolate: /\{\{(.+?)\}\}/g
        @grid_header_template_text = d3.select('.grid_header_template').html()
        @grid_header_template = _.template(@grid_header_template_text)
        @block_positions = null
        @swap_infos = new Array()

        $(obj).on('block_mouseover', (e) => @update_header(e.block))

    update_header: (block) =>
        obj = @
        @header.datum(block)
            .html((d) ->
                try
                    template_context =
                        block: d
                        position: obj.block_positions[d.id]
                    obj.grid_header_template(template_context)
                catch e
                    @_last_obj =
                        data: obj
                        block: d
            )

    set_zoom: (translate, scale, signal=true) =>
        @zoom.translate(translate)
        @zoom.scale(scale)
        @update_zoom(signal)

    update_zoom: (signal=true) =>
        @_update_zoom(@zoom.translate(), @zoom.scale(), signal)

    _update_zoom: (translate, scale, signal=true) =>
        transform_str = "translate(" + translate + ")" + " scale(" + scale + ")"
        @grid.attr("transform", transform_str)
        if signal
            obj = @
            $(obj).trigger(type: "zoom_updated", translate: translate, scale: scale)

    set_zoom_location: () =>
        transform_str = "translate(" + @zoom.translate() + ")" + " scale(" +
            @zoom.scale() + ")"
        window.location.hash = transform_str

    selected_fill_color: () -> @colors(@selected_fill_color_num)

    translate_block_positions: (block_positions) ->
        @_last_translated_positions = block_positions
        data = new Array()
        for position, i in block_positions
            item =
                block_id: i
                x: position[0]
                y: position[1]
                z: position[2]
                selected: false
                fill_opacity: 0.5
                stroke_width: 1
            data.push(item)
        @dims.x.max = Math.max(d3.max(item.x for item in data), @dims.x.max)
        @dims.x.min = Math.min(d3.min(item.x for item in data), @dims.x.min)
        @dims.y.max = Math.max(d3.max(item.y for item in data), @dims.y.max)
        @dims.y.min = Math.min(d3.min(item.y for item in data), @dims.y.min)
        for item in data
            if item.x < @dims.x.min + 1 or item.x > @dims.x.max - 1 or item.y < @dims.y.min + 1 or item.y > @dims.y.max - 1
                item.io = true
            else
                item.io = false
        @scale.x.domain([@dims.x.min, @dims.x.max + 1]).range([0, @width])
        @scale.y.domain([@dims.y.min, @dims.y.max + 1]).range([@width, 0])
        return data

    cell_width: () -> @scale.x(1)
    # Scale the height of each cell to the grid vertical height divided by the
    # number of blocks in the y-dimension.  Note that since `@scale.y` is
    # inverted*, we use `@dims.y.max` rather than 1 as the arg to `@scale.y` to
    # get the height of one cell.
    #
    # *see `translate_block_positions`
    cell_height: () -> @scale.y(@dims.y.max)
    block_width: () -> 0.8 * @cell_width()
    block_height: () -> 0.8 * @cell_height()
    block_color: (d) ->
        result = if d.io then @io_fill_color else d.fill_color
        return result
    cell_position: (d) => x: @scale.x(d.y), y: @scale.y(d.x)
    cell_center: (d) =>
        position = @cell_position d
        x: position.x + 0.5 * @cell_width(), y: position.y + 0.5 * @cell_height()

    clear_selection: () ->
        @_selected_blocks = {}
        #@update_selected_block_info()
        # Skip cell formatting until we can verify that it is working as
        # expected.
        #@update_cell_formats()

    select_block: (d) ->
        @_selected_blocks[d.block_id] = null
        #@update_selected_block_info()
        # Skip cell formatting until we can verify that it is working as
        # expected.
        #@update_cell_formats()

    deselect_block: (d) ->
        delete @_selected_blocks[d.block_id]
        #@update_selected_block_info()
        # Skip cell formatting until we can verify that it is working as
        # expected.
        #@update_cell_formats()

    selected_block_ids: () -> +v for v in Object.keys(@_selected_blocks)

    selected: (block_id) -> block_id of @_selected_blocks

    set_raw_block_positions: (raw_block_positions) ->
        @set_block_positions(@translate_block_positions(raw_block_positions))

    set_block_positions: (block_positions) ->
        @block_positions = block_positions
        @update_cell_data()
        # Skip cell formatting until we can verify that it is working as
        # expected.
        #@update_cell_formats()
        @update_cell_positions()
        #@update_selected_block_info()

    update_cell_data: () ->
        # Each tag of class `cell` is an SVG group tag.  Each such group
        # contains an SVG rectangle tag, corresponding to a block in the
        # placement grid.
        blocks = @grid.selectAll(".cell")
            .data(@block_positions, (d) -> d.block_id)

        obj = @

        blocks.enter()
            # For block ids that were not previously included in the bound data
            # set, create an SVG group and append an SVG rectangle to it for
            # the block
            .append("svg:g")
                .attr("class", "cell")
            .append("svg:rect")
                .attr("class", (d) -> "block block_" + d.block_id)
                .attr("width", @block_width())
                .attr("height", @block_height())
                .on('click', (d, i) ->
                    b = new Block(i)
                    $(obj).trigger(type: 'block_click', grid: obj, block: b, block_id: i, d: d)
                )
                .on('mouseout', (d, i) =>
                    b = new Block(i)
                    $(obj).trigger(type: 'block_mouseout', grid: obj, block: b, block_id: i, d: d)
                )
                .on('mouseover', (d, i) =>
                    b = new Block(i)
                    $(obj).trigger(type: 'block_mouseover', grid: obj, block: b, block_id: i, d: d)
                )
                .style("stroke", '#555')
                .style('fill-opacity', (d) -> d.fill_opacity)
                .style('stroke-width', (d) -> d.stroke_width)
                # Center block within cell
                .attr("transform", (d) =>
                    x_padding = (@cell_width() - @block_width()) / 2
                    y_padding = (@cell_height() - @block_height()) / 2
                    "translate(" + x_padding + "," + y_padding + ")")
        # Remove blocks that are no longer in the data set.
        blocks.exit().remove()

    update_cell_positions: () ->
        @grid.selectAll(".cell").transition()
            .duration(600)
            .ease("cubic-in-out")
            .attr("transform", (d) =>
                position = @cell_position d
                "translate(" + position.x + "," + position.y + ")")

    update_cell_formats: () ->
        obj = @
        blocks = @grid.selectAll(".cell").select(".block")
            .style("fill", (d) ->
                if obj.selected(d.block_id)
                    obj.selected_fill_color()
                else
                    obj.block_color(d)
            )
            .style("fill-opacity", (d) ->
                if obj.selected(d.block_id)
                    d.fill_opacity = 0.8
                else
                    d.fill_opacity = 0.5
                return d.fill_opacity
            )
            .style("stroke-width", (d) ->
                if obj.selected(d.block_id)
                    d.stroke_width = 4
                else
                    d.stroke_width = 1
                return d.stroke_width
            )

    highlight_area_range: (a) ->
        area_range_group = d3.select(".chart").append("svg:g")
            .attr("class", "area_range_group")
            .style("opacity", 0.75)
            .append("svg:rect")
            .attr("class", "area_range_outline")
            .attr("width", a.second_extent * @scale.x(1))
            .attr("height", a.first_extent * @scale.y(@dims.y.max))
            .on('mouseover', (d) ->
                d3.select(this).style("stroke-width", 10)
            )
            .on('mouseout', (d) ->
                d3.select(this).style("stroke-width", 7)
            )
            .style("fill", "none")
            .style("stroke", @colors((a.first_index * a.second_index) % 10))
            .style("stroke-width", 7)

        area_range_group.transition()
            .duration(400)
            .ease("cubic-in-out")
            .attr("transform", "translate(" + @scale.x(a.second_index) + ", " + @scale.y(a.first_index + a.first_extent - 1) + ")")


class AreaRange
    constructor: (@first_index, @second_index, @first_extent, @second_extent) ->

    contains: (point) ->
        return (point.x >= @first_index and point.x < @first_index + @first_extent and point.y >= @second_index and point.y < @second_index + @second_extent)


@PlacementGrid = PlacementGrid
@AreaRange = AreaRange
@Block = Block
@SwapContext = SwapContext
