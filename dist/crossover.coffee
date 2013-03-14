randomnumber=Math.floor(Math.random()*11)


do_swaps = (p, maps, count) ->
    #swap_order = _.shuffle(Object.keys(maps.b))
    swap_order = Object.keys(maps.b)
    count = Math.min(count, swap_order.length)

    # Make a copy of parent as a starting point
    c1 = $.extend(true, [], p)

    # Make a local copy of the from_map since we will be modifying it
    map = $.extend(true, {}, maps.a)

    if count > 0
        for i in [0..count - 1]
            key = swap_order[i]
            swap = source: map[key], target: maps.b[key]
            if c1[swap.target] of map
                map[c1[swap.target]] = swap.source
            [c1[swap.source], c1[swap.target]] = [c1[swap.target], c1[swap.source]]
    return c1


class ConfinedSwapCrossover
    constructor: (a, b) ->
        @p =
            a: a
            b: b
        @maps = a: {}, b: {}

        opposite = a: 'b', b: 'a'

        for label in ['a', 'b']
            for id, pos in @p[label]
                if id >= 0 and @p[opposite[label]][pos] != id
                    @maps[label][id] = pos

    do_swaps: (count) ->
        do_swaps(@p.a, @maps, count)


@do_swaps = do_swaps
@ConfinedSwapCrossover = ConfinedSwapCrossover
