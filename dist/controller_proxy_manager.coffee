class ControllerProxyManager
    constructor: () ->
        @controllers = {}

    add: (process_id, controller) =>
        @controllers[process_id] = controller
        obj = @
        process_info = process_id: process_id, controller: controller
        c = new PlacementCollector([process_info])

        c.collect('get_net_to_block_id_list', (results) =>
            controller.net_to_block_ids = results[0].result
            c.collect('get_block_to_net_ids', (results) =>
                controller.block_to_net_ids = results[0].result
                c.collect('get_block_net_counts', (results) =>
                    controller.block_net_counts = results[0]
                )
            )
            $(obj).trigger(type: "controller_added", process_id: process_id, controller: controller)
        )

    remove: (process_id) =>
        delete @controllers[process_id]
        obj = @
        $(obj).trigger(type: "controller_removed", process_id: process_id)

    controller_list: () => (process_id: k, controller: v for k,v of @controllers)

@ControllerProxyManager = ControllerProxyManager
