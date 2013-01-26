class Placement
    constructor: (options) ->
        @block_positions = options.block_positions
        @net_to_block_ids = options.net_to_block_ids
        @block_to_net_ids = options.block_to_net_ids
        @block_net_counts = options.block_net_counts
    apply_swaps: (swap_context) ->
        options =
            block_positions: swap_context.apply_swaps(@block_positions)
            net_to_block_ids: @net_to_block_ids
            block_to_net_ids: @block_to_net_ids
            block_net_counts: @block_net_counts
        new Placement(options)


class PlacementManager
    constructor: () ->
        @placements = []
        @swap_contexts = {}
    append_placement: (placement) ->
        @placements.push(placement)
        obj = @
        $(obj).trigger(type: "placement_added", placement: placement)
        placement
    append_swap_context: (swap_context) ->
        i = @placements.length
        placement = @placements[i - 1]
        placement.apply_swaps(swap_context)
        @placements.push(placement)
        @swap_contexts[i] = swap_context
        $(@).trigger(type: "swap_context_added",
                       swap_context: swap_context,
                       swap_context_i: i)
        $(@).trigger(type: "placement_added", placement: placement)
        placement


@PlacementManager = PlacementManager
@Placement = Placement
