
function fs.symlink(location, target, impersonateRoot)
  location = fs.combine(location, "")
  target = fs.combine(target, "")

  local symfs = {}

  function inTarget(method)
    symfs[method] = function(fs, path, ...)
      return fs[method](fs.combine(target, path), ...)
    end
  end

  inTarget("list")
  inTarget("getSize")
  inTarget("exists")
  inTarget("isDir")
  inTarget("isReadOnly")
  inTarget("makeDir")
  inTarget("delete")
  inTarget("open")
  inTarget("getDrive")
  inTarget("getFreeSpace")

  inTarget("getName")

  function symfs.getDir(fs, path, ...)
    return fs.getDir(fs.combine(location, path), ...)
  end


  inTarget("isDriveRoot")
  inTarget("getCapacity")
  inTarget("attributes")

  function symfs.find(fs, name)
    return _.map(fs.find(fs.combine(target, name)), function(p) return string.sub(p, #target + 1) end)
  end

  function symfs.copy(fs, a, b)
    return fs.copy(fs.combine(target, a), fs.combine(target, b))
  end

  function symfs.move(fs, a, b)
    return fs.move(fs.combine(target, a), fs.combine(target, b))
  end

  function symfs.moveOut(fs, a, b)
    return fs.move(fs.combine(target, a), b)
  end

  function symfs.moveIn(fs, a, b)
    return fs.move(a, fs.combine(target, b))
  end

  fs.mount(location, symfs)
end
