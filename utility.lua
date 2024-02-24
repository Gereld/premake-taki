local utility = {}

function utility.splitAtDot(str)
  local result = {}
  for sub in str:gmatch("([^".."%.".."]+)") do
    table.insert(result, sub)
  end
  return result
end

function utility.access(path, context)
  local path = utility.splitAtDot(path)
  local result = context
  for _, node in ipairs(path) do
    result = result[node]
    if not result then
      return nil
    end
  end
  return result
end

function utility.resolve(str, context, default)
  local function findTokens(str)
    local result = {}
    local pos = 1
    repeat
      local b, e = str:find("%%{[^}]+}", pos)
      if not b then
        break
      end
      table.insert(result, { first = b, last = e, token = str:sub(b, e) })
      pos = e + 1
    until not b
    return result
  end

  local function resolveWithTokens(str, tokens)
    local result = ""
    local pos = 1
    for _, token in ipairs(tokens) do
      result = result .. str:sub(pos, token.first - 1)
      pos = token.last + 1
      local path = token.token:sub(3, token.token:len() - 1)
      local value = utility.access(path, context)
      if not value then
        if not default then
          value = token.token
        elseif type(default) == 'function' then
          value = default(path)
        else
          value = default
        end
      end
      result = result .. value
    end
    result = result .. str:sub(pos, str:len())
    return result
  end

  local tokens = findTokens(str)
  return resolveWithTokens(str, tokens)
end

function utility.mapTable(list, fn, ...)
  local arg = {...}
  local result = {}
  local n = #list
  for i = 1, n do
    result[i] = fn(list[i], table.unpack(arg))
  end
  return result
end

function utility.map(object, fn, ...)
  if type(object) == 'table' then
    return utility.mapTable(object, fn, table.unpack({...}))
  elseif object then
    return fn(object)
  end
end

function utility.dump(o)
  if type(o) == 'table' then
    local s = '{ '
    for k,v in pairs(o) do
       if type(k) ~= 'number' then k = '"'..k..'"' end
       s = s .. '['..k..'] = ' .. utility.dump(v) .. ', '
    end
    return s .. '} '
  else
    return tostring(o)
  end
end

return utility
