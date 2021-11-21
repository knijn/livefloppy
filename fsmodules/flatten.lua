local tree = {_type = "dir"; _flat = {}}

local utils = {}

function utils.get(args)
    local cur = tree
    for i = 1, #args do
        if cur ~= nil and cur._type == "dir" then
            cur = cur[args[i]]
        else
            return nil
        end
    end
    return cur
end

function utils.makeDir(args)
    local cur = tree
    for i = 1, #args do
        if cur._type ~= "dir" then
            error("Cannot make dir in non-directory")
        else
            local a = cur[args[i]]
            if a == nil then
                a = {_type = "dir"}
                cur[args[i]] = a
                cur = a
            else
                cur = a
            end
        end
    end
    return cur
end

function utils.makeFile(args)
    local dir = utils.makeDir()
    local name = args[#args]
    args[#args] = nil
    local dir = utils.makeDir(args)
    if dir[name] ~= nil then
        error("File already exists")
    else
        local file = {_type = "file"; _id = tostring(math.random())}
        dir[name] = file
        return file
    end
end

function utils.loadTree(str)
    local loadedtree = textutils.unserialise(str)
    if type(loadedtree) == "table" and loadedtree._type == "dir" then
        tree = loadedtree
    else
        error("String does not contain proper tree")
    end
end

function utils.saveTree()
    return textutils.serialise(tree)
end

_G.treeutils = utils

function split (inputstr, sep)   if sep == nil then       sep = "%s"   end   local t={}   for str in string.gmatch(inputstr, "([^"..sep.."]+)") do           table.insert(t, str)   end   return t end

function fs.flatten(location)
  location = fs.combine(location, "")

  local treefile = fs.combine(location, ".tree")

  function loadTree(fs)
    if fs.exists(treefile) and not fs.isDir(treefile) then
      local file = fs.open(treefile, "r")
      utils.loadTree(file.readAll())
      file.close()
    end
  end

  function saveTree(fs)
    local file = fs.open(treefile, "w")
    file.write(utils.saveTree())
    file.close()
  end

  -- Load the current tree.
  loadTree(fs)

  local flatfs = {}

  function splitPath(fs, p)
    p = fs.combine(p, "")
    return split(p, "/")
  end

  function flatfs.list(fs, p)
    local dir = utils.get(splitPath(fs, p))
    if dir ~= nil and dir._type == "dir" then
        local files = {}
        for k,v in pairs(dir) do
            if string.sub(k, 1, 1) ~= "_" then
                files[#files + 1] = k
            end
        end
        return files
    else
        error("Is not a directory: " .. fs.combine(location, p))
    end
  end

  function unsupport(name)
    flatfs[name] = function () error("Function " .. name .. " is not supported") end
  end

  unsupport("getSize")

  function flatfs.exists(fs, path)
    return utils.get(splitPath(fs, path)) ~= nil
  end
  
  function flatfs.isDir(fs, path)
    local test = utils.get(splitPath(fs, path))
    return (test ~= nil and test._type == "dir")
  end

  function flatfs.isReadOnly(fs, path)
    return false
  end

  function flatfs.delete(fs, path)
    path = fs.combine(path, "")
    if path == "" then
      return fs.delete(fs.combine(location, path))
    end
    local pathpar, pathname = fs.getDir(path), fs.getName(path)

    local parent = utils.get(splitPath(fs, pathpar))
    if parent == nil or parent[pathname] == nil then
      return nil
    end
    local files = {}
    function overTree(dir)
      if dir._type == "file" then
        files[#files + 1] = dir._id
      else
        for i, v in pairs(dir) do
          if string.sub(i, 1, 1) ~= "_" then
            overTree(v)
          end
        end
      end
    end
    overTree(parent[pathname])
    parent[pathname] = nil
    for i, file in pairs(files) do
      fs.delete(fs.combine(location, file))
    end
    saveTree(fs)
  end

  function flatfs.makeDir(fs, p)
    utils.makeDir(splitPath(fs, p))
    saveTree(fs)
  end

  function flatfs.open(fs, p, mode)
    if mode == "w" or mode == "wb" or mode == "a" then
      local args = splitPath(fs, p)
      local file = utils.get(args)
      if file == nil then
        file = utils.makeFile(args)
        saveTree(fs)
      end
      if file._type ~= "file" then
        error("Cannot open directory")
      end
      return fs.open(fs.combine(location, file._id), mode)
    else
      local file = utils.get(splitPath(fs, p))
      if file == nil then
        return nil, "File "..p.." does not exist"
      end
      if file._type ~= "file" then
        error("Cannot open directory")
      end
      return fs.open(fs.combine(location, file._id), mode)
    end
  end

  function flatfs.getDrive(fs, p)
    return fs.getDrive(location)
  end

  function flatfs.getFreeSpace(fs, p)
    return fs.getFreeSpace(location)
  end

  function flatfs.getName(fs, path, ...)
    return fs.getName(fs.combine(location, path), ...)
  end

  function flatfs.getDir(fs, path, ...)
    return fs.getDir(fs.combine(location, path), ...)
  end


  function flatfs.isDriveRoot(fs, p)
    return fs.isDriveRoot(location)
  end
  function flatfs.getCapacity(fs, p)
    return fs.getCapacity(location)
  end
  
  unsupport("attributes")

  function flatfs.find(fs, path)
    local args = splitPath(fs, path)
    local pattern = args[#args]
    args[#args] = nil
    local parent = utils.get(args)
    if parent == nil or pattern == nil then
      return {}
    else
      local l, r = pattern:match("(.*)\*(.*)")
      local matches = {}
      for i, _v in pairs(parent) do
        if i:sub(1, 1) ~= "_" then
          if l == nil and i == pattern then
            matches[#matches + 1] = i
          elseif l ~= nil and i:sub(1, #l) == l and i:sub(#i - #r + 1) == r then
            matches[#matches + 1] = i
          end
        end
      end
      return matches
    end
  end

  unsupport("copy")
  unsupport("move")
  unsupport("moveOut")
  unsupport("moveIn")

  fs.mount(location, flatfs)
end
