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

    update_selected_block_info: () ->
        data = (@block_positions[block_id] for block_id in @selected_block_ids())
        infos = @selected_container.selectAll(".placement_info")
            .data(data, (d) -> d.block_id)
        infos.enter()
          .append("div")
            .attr("class", "placement_info")
        infos.exit().remove()
        infos.html((d) -> placement_grid.template($().extend({net_ids: ''}, d)))

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

    reset_block_formats: ->
        blocks = @grid.selectAll('.block')
            .style("stroke", '#555')
            .style("fill", "black")
            .style('opacity', 1.0)
            .style('stroke-width', 1.0)

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
