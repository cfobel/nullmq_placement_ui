class @PlacementGrid
    constructor: (@id, @width) ->
        @grid = d3.select(@id)
                        .append("svg")
                        .attr("width", @width)
                        .attr("height", @width)
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
        @scale.x.domain([@dims.x.min, @dims.x.max]).range([0, @width])
        @scale.y.domain([@dims.y.min, @dims.y.max]).range([@width, 0])
        @block_positions = data

    set_data: (raw_block_positions) ->
        @set_block_positions(raw_block_positions)

        @blocks = @grid.selectAll(".cell")
              .data(@block_positions)
            .enter()
            .append("svg:g")
             .attr("transform", (d) => "translate(" + @scale.x(d.x) + "," + @scale.y(d.y) + ")")
        @draw()

    draw: () ->
        colors = d3.scale.category10().domain(d3.range(10))
        @blocks.append("svg:rect")
            .attr("class", "block")
            .attr("width", @scale.x(1))
            .attr("height", @scale.y(@dims.y.max - 1))
            .on('click', (d) ->
                d.selected = !d.selected
                color = if d.selected then colors(1) else colors(9)
                d3.select(this).style('fill', color)
            )
            .on('mouseover', (d) ->
                text_element = d3.select("#block_id").text(d.block_id)
                text_element = d3.select("#block_coordinates").text("(" + d.x + ", " + d.y + ")")
            )
            .style("fill", colors(9))
            .style("stroke", '#555')
###
        @blocks.append("svg:text")
            .attr("transform", "translate(" + (@scale.x(1) / 2.0) + "," + (@scale.y(@dims.y.max - 1) / 2.0) + ")")
            .attr("text-anchor", "middle")
            .text((d) -> d.block_id)
###
