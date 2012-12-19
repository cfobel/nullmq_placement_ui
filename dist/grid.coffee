class @PlacementGrid
    constructor: (@id, @width) ->
        @grid = d3.select(@id)
                        .append("svg")
                        .attr("width", 1.1 * @width)
                        .attr("height", 1.5 * @width)
                        .attr("class", "chart")
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
        @selected_fill_color = @colors(2)
        @io_fill_color = @colors(1)
        @clb_fill_color = @colors(9)
        @selected_blocks = {}
        _.templateSettings =
          interpolate: /\{\{(.+?)\}\}/g
        @template_text = d3.select("#placement_info_template").html()
        @template = _.template(@template_text)

    set_block_positions: (block_positions) ->
        data = new Array()
        for position, i in block_positions
            item =
                block_id: i
                x: position[0]
                y: position[1]
                z: position[2]
                selected: false
            data.push(item)
            @dims.x.max = Math.max(item.x, @dims.x.max)
            @dims.x.min = Math.min(item.x, @dims.x.min)
            @dims.y.max = Math.max(item.y, @dims.y.max)
            @dims.y.min = Math.min(item.y, @dims.y.min)
        for item in data
            if item.x < @dims.x.min + 1 or item.x > @dims.x.max - 1 or item.y < @dims.y.min + 1 or item.y > @dims.y.max - 1
                item.io = true
            else
                item.io = false
        @scale.x.domain([@dims.x.min, @dims.x.max + 1]).range([0, @width])
        @scale.y.domain([@dims.y.min, @dims.y.max + 1]).range([@width, 0])
        @block_positions = data

    set_data: (raw_block_positions) ->
        @set_block_positions(raw_block_positions)

        @blocks = @grid.selectAll(".cell")
              .data(@block_positions)
            .enter()
            .append("svg:g")
             .attr("transform", (d) => "translate(" + @scale.x(d.x) + "," + @scale.y(d.y) + ")")
        @draw()

    block_color: (d) -> if d.io then @io_fill_color else @clb_fill_color

    select_block: (d) ->
        @selected_blocks[d.block_id] = d
        @update_block_info()

    deselect_block: (d) ->
        delete @selected_blocks[d.block_id]
        @update_block_info()

    update_block_info: () ->
        blocks = new Array()
        for block_id,block of @selected_blocks
            blocks.push(block)
        placement_infos = d3.select("#placement_info_selected")
                .selectAll(".placement_info")
                .data(blocks, (d) -> d.block_id)
        placement_infos.enter()
                .append("div")
                .attr("class", "placement_info")
                .html((d) -> placement_grid.template(d));
        placement_infos.exit().remove();

    draw: () ->
        context = @
        @blocks.append("svg:rect")
            .attr("class", "block")
            .attr("width", @scale.x(1))
            .attr("height", @scale.y(@dims.y.max))
            .on('click', (d) ->
                # Toggle selected state of clicked block
                obj = context
                d.selected = !d.selected
                color = if d.selected then obj.selected_fill_color else obj.block_color(d)
                opacity = if d.selected then 0.9 else 0.5
                stroke_width = if d.selected then 3 else 1
                d3.select(this)
                    .style('fill', color)
                    .style('fill-opacity', opacity)
                    .style('stroke-width', stroke_width)
                if d.selected
                    obj.select_block(d)
                else
                    obj.deselect_block(d)
            )
            .on('mouseover', (d) ->
                # Update current block info table
                current_info = d3.select("#placement_info_current")
                        .selectAll(".placement_info")
                        .data([d], (d) -> d.block_id)
                current_info.enter()
                        .append("div")
                        .attr("class", "placement_info")
                        .html((d) -> placement_grid.template(d))
                current_info.exit().remove()
            )
            .style("fill", (d) => @block_color(d))
            .style("stroke", '#555')
            .style('fill-opacity', 0.5)
###
        @blocks.append("svg:text")
            .attr("transform", "translate(" + (@scale.x(1) / 2.0) + "," + (@scale.y(@dims.y.max) / 2.0) + ")")
            .attr("text-anchor", "middle")
            .text((d) -> d.block_id)
###
