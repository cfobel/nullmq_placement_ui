class ControllerProxyManager
    constructor: () ->
        @controllers = {}

    add: (process_id, controller) =>
        @controllers[process_id] = controller
        obj = @
        process_info = process_id: process_id, controller: controller
        $(obj).trigger(type: "controller_added", process_id: process_id, controller: controller)

    remove: (process_id) =>
        delete @controllers[process_id]
        obj = @
        $(obj).trigger(type: "controller_removed", process_id: process_id)

    make_manager: (process_id) =>
        kwargs =
            command: "make_manager"
            kwargs: process_id: process_id
        obj = @
        _on_response = (response) ->
            controller.manager_uri = response.result.manager_control_rep_uri
            event_data =
                type: "manager_added"
                process_id: process_id
                controller_proxy_manager: obj
                controller: controller
                manager_uri: controller.manager_uri
            $(obj).trigger(event_data)
        @controllers[process_id].do_command(kwargs, on_response)

    controller_list: () => (process_id: k, controller: v for k,v of @controllers)

@ControllerProxyManager = ControllerProxyManager
