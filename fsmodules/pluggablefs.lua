local function copyTable(a, b)
  for i,v in pairs(a) do
    b[i] = v
  end
  return b
end

local oldfs = copyTable(_G.fs, {})

function clean(path)
  return oldfs.combine(path, "")
end

local function getMount(mounts, path)
  path = clean(path)
  if #mounts == 0 or path:sub(1,2) == ".." then
    return false
  else
    local initial = _.initial(mounts)
    local last = _.last(mounts)
    if last.path == "" or path == last.path or path:sub(1,#(last.path)+1) == last.path .. "/" then
      return {fs = last.fs, path = path:sub(#(last.path) + 1), mount = last.path}, initial
    else
      return getMount(initial, path)
    end
  end
end

local function getMountWith(mounts, path, func)
  local mount, rest = getMount(mounts, path)
  if (not mount) or mount.fs[func] then
    return mount, rest
  else
    return getMountWith(rest, path, func)
  end
end


local function fsWithMounts(mounts)
  local fs = {}

  function tryMount(func)
    function inner (path, ...)
      local mount, rest = getMount(mounts, path)
      if mount then
        local innerfs = fsWithMounts(rest)
        if mount.fs[func] then
          return mount.fs[func](innerfs, mount.path, ...)
        else
          return fsWithMounts(rest)[func](path, ...)
        end
      else
        return oldfs[func](path, ...)
      end
    end
    return inner
  end

  function tryMountTransform(func, transform)
    function inner (path, ...)
      local mount, rest = getMount(mounts, path)
      if mount then
        local innerfs = fsWithMounts(rest)
        if mount.fs[func] then
          return transform(innerfs, mount, mount.fs[func](innerfs, mount.path, ...))
        else
          return fsWithMounts(rest)[func](path, ...)
        end
      else
        return oldfs[func](path, ...)
      end
    end
    return inner
  end

  fs.list = tryMount("list")

  fs.getName = tryMount("getName")

  fs.getSize = tryMount("getSize")

  fs.exists = tryMount("exists")

  fs.isDir = tryMount("isDir")

  fs.isReadOnly = tryMount("isReadOnly")

  fs.makeDir = tryMount("makeDir")

  fs.delete = tryMount("delete")

  fs.open = tryMount("open")

  fs.getDrive = tryMount("getDrive")

  fs.getFreeSpace = tryMount("getFreeSpace")

  fs.getDir = tryMount("getDir")

  fs.isDriveRoot = tryMount("isDriveRoot")

  fs.getCapacity = tryMount("getCapacity")

  fs.attibutes = tryMount("attributes")

  function fs.combine(a,b)
    return oldfs.combine(a,b)
  end

  function fs.copy (patha, pathb)
    patha = clean(patha)
    pathb = clean(pathb)
    if fs.exists(pathb) then
      error(pathb..": File exists")
    elseif not fs.exists(patha) then
      error(patha..": File does not exist")
    elseif fs.isReadOnly(pathb) then
      error(pathb..": File read only")
    end

    function innerCopy(patha, pathb)
      if fs.isDir(patha) then
        fs.makeDir(pathb)
        for _, name in pairs(fs.list(patha)) do
          innerCopy(fs.combine(patha, name), fs.combine(pathb, name))
        end
      else
        local writeFile = fs.open(pathb, "w")
        local readFile = fs.open(patha, "r")
        writeFile.write(readFile.readAll())
        writeFile.close()
        readFile.close()
      end
    end

    innerCopy(patha, pathb)
  end

  function fs.move(patha, pathb)
    patha = clean(patha)
    pathb = clean(pathb)
    if fs.isReadOnly(patha) then
      error(patha..": File read only")
    end

    local mounta, resta = getMountWith(mounts, patha, "move")
    local mountb, restb = getMountWith(mounts, pathb, "move")
    if mounta and mountb and mounta.fs == mountb.fs then
      local innerfs = fsWithMounts(resta)
      return mounta.fs["move"](innerfs, mounta.path, mountb.path)
    end

    -- Fallback?
    fs.copy(patha, pathb)
    fs.delete(patha)
  end

  fs.find = tryMountTransform("find", function(fs, mount, list) return _.map(list, function(p) return fs.combine(mount.mount, p) end) end)

  fs.complete = oldfs.complete

  return fs
end

local allMounts = {}
local fs = fsWithMounts(allMounts)


function fs.mount(path, mount)
  path = clean(path)
  if not fs.isDir(path) then
    error("Must mount in dir")
  elseif fs.isReadOnly(path) then
    error("Cannot mount in read-only place")
  else
    allMounts[#allMounts + 1] = {fs = mount, path = path}
  end
end

copyTable(fs, _G.fs)
