
function deepget(obj, ...)
    for _, k in pairs({...}) do
        if obj == nil then return obj end
        obj = obj[k]
    end
    return obj
end

function deepcopy(obj)
    if type(obj) ~= 'table' then return obj end
    local res = setmetatable({}, getmetatable(obj))
    for k, v in pairs(obj) do res[deepcopy(k)] = deepcopy(v) end
    return res
end
