set_options = (values, dropdown) =>
    dropdown.empty()
    for v in values
        $("<option />", val: v, text: v).appendTo(dropdown)


set_paths = (paths, dropdown) =>
    dropdown.empty()
    for p in paths
        path_components = p.split('/')
        name = path_components[path_components.length - 1]
        $("<option />", val: p, text: name).appendTo(dropdown)


last = (data) -> data[data.length - 1]


split_last = (data, delimiter) -> last(data.split(delimiter))


json_compare = (a, b) ->
    [a, b] = (JSON.stringify(v) for v in [a, b])
    return a == b


@coffee_helpers = 
    set_options: set_options
    set_paths: set_paths
    last: last
    split_last: split_last
    json_compare: json_compare
