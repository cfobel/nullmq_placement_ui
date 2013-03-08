class PlacementManagerGrid extends PlacementGrid
    constructor: (@placement_manager, @id, @width=null) ->
        super @id, @width
        @refresh_keys()

    refresh_keys: () ->
        ###
        # Request placement keys
        #  * Request swap context keys
        #   * Update local keys list with union of placement keys and swap
        #     context keys
        #   * If no current placement is set, select the placement
        #     corresponding to the first key (if available)
        ###
        @placement_manager.get_placement_keys((placement_keys) =>
            @placement_manager.get_swap_context_keys((swap_context_keys) =>
                keys_dict = {}
                for k in placement_keys
                    keys_dict[k] = k
                for k in swap_context_keys
                    keys_dict[k] = k
                keys = (v for k, v of keys_dict)
                console.log('keys', keys)
            )
        )

    select_key: (key) ->
        ###
        # When a new key is selected, we must:
        #
        #  * Uncheck and disable `Show swaps` and `Apply swaps` checkboxes
        #  * Request placement
        #   * Update grid with placement
        #   * Update `current_key`
        #   * Request configuration
        #    * If configuration returned, highlight area ranges (if available)
        #    * Request swap context
        #     * Enable `Show swaps` and `Apply swaps` checkboxes
        #     * Show swaps by default:
        #      * Apply swaps formatting (i.e., `swaps_show(true)`)
        #      * Check `Show swaps` checkbox
        ###

    swaps_show: (state) ->
        ###
        # state=true (false->true)
        #
        #  * Set swap data
        #  * Apply block formats to grid
        #  * Apply swap-link formats
        #
        #
        # state=false (true->false)
        #
        #  * Remove all swap-related block formatting
        #  * Remove all swap-link elements
        ###

    swaps_apply: (state) ->
        ###
        # state=true (false->true)
        #
        #  * Update grid block positions to positions after applying swaps from
        #    swap context.
        #
        #
        # state=false (true->false)
        #
        #  * Update grid block positions to positions in the current placement.
        ###

@PlacementManagerGrid = PlacementManagerGrid
