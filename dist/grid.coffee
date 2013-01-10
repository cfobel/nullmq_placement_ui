class PlacementGrid
    update_zoom: (translate, scale) =>
        #console.log([translate, scale])
        transform_str = "translate(" + @zoom.translate() + ")" + " scale(" +
            @zoom.scale() + ")"
        @grid.attr("transform", transform_str)
    set_zoom_location: () =>
        transform_str = "translate(" + @zoom.translate() + ")" + " scale(" +
            @zoom.scale() + ")"
        window.location.hash = transform_str
    constructor: (@id, @width) ->
        @zoom = d3.behavior.zoom()
        @grid = d3.select("#" + @id)
                    .append("svg")
                        .attr("width", 1.1 * @width)
                        .attr("height", 1.1 * @width)
                    .append('svg:g')
                        .attr("id", @id + "_transform_group")
                        .call(@zoom.on("zoom", () => @update_zoom(d3.event.translate, d3.event.scale)))
                    .append('svg:g')
                        .attr("class", "chart")
        zoom = window.location.hash
        result = /#translate\((-?\d+\.\d+),(-?\d+\.\d+)\)\s+scale\((-?\d+\.\d+)\)/.exec(zoom)
        if result and result.length == 4
            [translate_x, translate_y, scale] = result[1..]
            console.log(result)
            @zoom.scale(scale)
            @zoom.translate([translate_x, translate_y])
            @update_zoom()
        else
            console.log(zoom)
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
        @selected_blocks = {}
        _.templateSettings =
          interpolate: /\{\{(.+?)\}\}/g
        @template_text = d3.select("#placement_info_template").html()
        @template = _.template(@template_text)
        @selected_container = d3.select("#placement_info_selected")
        @block_positions = null
        @batch_block_positions = new Array()
        @batch_color_num = 2
        @batch_styles = new Array()
        @batch_i = 0
        @swap_infos = new Array()
        @block_mouseover = (d, i, rect) ->
                rect.style("fill-opacity", 1.0)
                    .style("stroke-width", 6)
                # Update current block info table
                current_info = d3.select("#placement_info_current")
                        .selectAll(".placement_info")
                        .data([d], (d) -> d.block_id)
                current_info.enter()
                        .append("div")
                        .attr("class", "placement_info")
                        .html((d) -> placement_grid.template(d))
                current_info.exit().remove()
        @block_mouseout = (d, i, rect) ->
                rect.style("fill-opacity", d.fill_opacity)
                    .style("stroke-width", d.stroke_width)

    connect: d3.svg.diagonal()
    set_swap_links: (swap_context) ->
        @swap_infos = swap_context.all
        swap_links = @grid.selectAll(".link").data(@swap_infos)
        swap_links.enter()
            .append("svg:path")
            .attr("class", "link")
            .style("fill", "none")
            .style("pointer-events", "none")
            .style("stroke", "none")
            .style("stroke-width", 1.5)
            .style("opacity", 0)
        swap_links.exit().remove()

        swap_links.transition()
            .duration(200)
            .ease("cubic-in-out")
            .style("opacity", (d) ->
                if d.swap_result.swap_accepted
                    return 0.9
                else if not d.swap_config.participate
                    return 0.25
                else
                    return 0.35
            )
            .style("stroke", (d) ->
                if d.swap_result.swap_accepted
                    return "#060"
                else if not d.swap_config.participate
                    return "#D00"
                else
                    return "#FFB300"
            )
            .attr("d", (d) =>
                [from_x, from_y] = d.swap_config.coords.from_
                from_coords = x: from_x, y: from_y
                [from_x, from_y] = d.swap_config.coords.to
                to_coords = x: from_x, y: from_y
                @connect.source(@cell_center(from_coords))
                    .target(@cell_center(to_coords))()
            )
        console.log(["current block positions", @block_positions])

    selected_fill_color: () -> @colors(@selected_fill_color_num)

    translate_block_positions: (block_positions) ->
        console.log(["translate_block_positions", block_positions])
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
                batch_index: @batch_i
                fill_color: @batch_styles[@batch_i].fill_color
            if @batch_i > 0
                old_item = @batch_block_positions[@batch_i - 1][i]
                if old_item.x == item.x and old_item.y == item.y
                    item.fill_color = old_item.fill_color
                    item.moved = false
                else
                    item.moved = true
                item.selected = old_item.selected
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
        for block_id,block of @selected_blocks
            block.selected = false
        @selected_blocks = {}
        @update_block_info()
        @update_cells()

    select_block: (d) ->
        @selected_blocks[d.block_id] = d
        @update_block_info()
        @update_cells()

    deselect_block: (d) ->
        delete @selected_blocks[d.block_id]
        @update_block_info()
        @update_cells()

    selected_block_values: () -> (block for block_id,block of @selected_blocks)

    update_selected_block_info: () ->
        block_objs = @selected_block_values()
        infos = @selected_container.selectAll(".placement_info")
                .data(block_objs, (d) -> d.block_id)
        infos.enter()
                .append("div")
                .attr("class", "placement_info")
        infos.exit().remove()
        infos.html((d) -> placement_grid.template(d))

    set_raw_block_positions: (raw_block_positions) ->
        @batch_styles.push({"fill_color": @colors(@batch_color_num)})
        @set_block_positions(@translate_block_positions(raw_block_positions))

    set_block_positions: (block_positions) ->
        @batch_i = @batch_block_positions.length
        console.log("block_positions", @batch_block_positions)
        @batch_color_num += 3
        @block_positions = block_positions
        @batch_block_positions.push(@block_positions)
        @update_selected_block_info()
        @update_cells()
        console.log("batch_styles", @batch_styles)
        @batch_styles.push({"fill_color": @colors(@batch_color_num)})

    update_cells: () ->
        # Each tag of class `cell` is an SVG group tag.  Each such group
        # contains an SVG rectangle tag, corresponding to a block in the
        # placement grid.
        @blocks = @grid.selectAll(".cell")
            .data(@block_positions, (d) -> d.block_id)
        obj = @
        @blocks.enter()
            # For block ids that were not previously included in the bound data
            # set, create an SVG group and append an SVG rectangle to it for
            # the block
            .append("svg:g")
            .attr("class", "cell")
            .append("svg:rect")
            .attr("class", "block")
            .attr("width", @block_width())
            .attr("height", @block_height())
            .attr("id", (d) -> "id_block_" + d.block_id)
            .on('click', (d) ->
                # Toggle selected state of clicked block
                d.selected = !d.selected
                if d.selected
                    obj.select_block(d)
                else
                    obj.deselect_block(d)
            )
            .on('mouseout', (d, i) =>
                @block_mouseout(d, i, d3.select("#id_block_" + i))
            )
            .on('mouseover', (d, i) =>
                @block_mouseover(d, i, d3.select("#id_block_" + i))
            )
            .style("stroke", '#555')
            .style('fill-opacity', (d) -> d.fill_opacity)
            .style('stroke-width', (d) -> d.stroke_width)
            # Center block within cell
            .attr("transform", (d) =>
                x_padding = (@cell_width() - @block_width()) / 2
                y_padding = (@cell_height() - @block_height()) / 2
                "translate(" + x_padding + "," + y_padding + ")")
        @blocks.exit().remove()

        @blocks.transition()
            .duration(600)
            .ease("cubic-in-out")
            .attr("transform", (d) =>
                position = @cell_position d
                "translate(" + position.x + "," + position.y + ")")

        @blocks.select(".block")
            .style("fill", (d) -> if d.selected then obj.selected_fill_color() else obj.block_color(d))
            .style("fill-opacity", (d) ->
                if d.selected
                    d.fill_opacity = 0.8
                else
                    d.fill_opacity = 0.5
                return d.fill_opacity
            )
            .style("stroke-width", (d) ->
                if d.selected
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
