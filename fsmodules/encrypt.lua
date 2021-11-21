local chacha = require("chacha")
local sha = require("sha256")
--local b64 = require("base64")

local b64 = {}

function b64.encode(s)
  local i = string.char(1)
  local o = string.char(2)
  local t = string.char(3)
  s = s:gsub(t, i..i..o..t)
  s = s:gsub(o, o..o..o..t)
  s = s:gsub(i, o..o..i..t)
  s = s:gsub(string.char(0), o..i..o..t)
  s = s:gsub(string.char(10), o..i..i..t)
  s = s:gsub(string.char(13), i..o..o..t)
  s = s:gsub(string.char(9), i..o..i..t)
  return s
end

function b64.decode(s)
  local i = string.char(1)
  local o = string.char(2)
  local t = string.char(3)
  s = s:gsub(o..i..o..t, string.char(0))
  s = s:gsub(o..i..i..t, string.char(10))
  s = s:gsub(i..o..o..t, string.char(13))
  s = s:gsub(i..o..i..t, string.char(9))
  s = s:gsub(o..o..i..t, i)
  s = s:gsub(o..o..o..t, o)
  s = s:gsub(i..i..o..t, t)
  return s
end


function stringReader(str)

  local index = 1

  local file = {}

  function file.readAll()
    local res = str:sub(index)
    index = #str + 1
    return res
  end

  function file.read(count)
    local res = str:sub(index, index+count - 1)
    index = index + count
    if res == "" then
      return nil
    else
      return res
    end
  end

  function file.readLine(trailing)
    if index > #str then
      return nil
    end
    local ni = str:find("\n", index, false)
    if ni == nil then
      local res = str:sub(index)
      index = #str + 1
      return res
    else
      local ni2
      if trailing then ni2 = ni else ni2 = ni - 1 end
      local res = str:sub(index, ni2)
      index = ni + 1
      return res
    end
  end

  function file.close()
    -- Nothing to do here
  end

  return file
end

function stringWriter(str, onflush)

  local file = {}

  function file.write(line)
    str = str .. line
  end

  function file.writeLine(line)
    str = str .. line .. "\n"
  end

  function file.flush()
    if str ~= nil then
      onflush(str)
    else
      error("File closed")
    end
  end

  function file.close()
    if str ~= nil then
      onflush(str)
      str = nil
    else
      error("File closed")
    end
  end

  return file
end


_G.stringReader = stringReader
_G.stringWriter = stringWriter


function fs.encrypt(location, key)
  location = fs.combine(location, "")

  local encfs = {}

  function copy(method)
    encfs[method] = function(fs, path, ...)
      return fs[method](fs.combine(location, path), ...)
    end
  end

  -- ENCRYPTION
  
  local key = sha.digest(key)  
  
  local nonce
  local noncefile = fs.combine(location, ".nonce")
  if fs.exists(noncefile) then
      local file = fs.open(noncefile, "r")
      nonce = textutils.unserialise(file.readAll())
      file.close()
  else
      nonce = chacha.genNonce(12)
      local file = fs.open(noncefile, "w")
      file.write(textutils.serialise(nonce))
      file.close()
  end

  function encode(text)
    return b64.encode(tostring(chacha.crypt(text, key, nonce, 1, 8)))
  end

  function decode(text)
    return tostring(chacha.crypt(b64.decode(text), key, nonce, 1, 8))
  end

  -- VERIFY THE KEY
  local challengeFile = fs.combine(location, ".challenge")
  local challengeFile2 = fs.combine(location, ".challenge.enc")
  if fs.exists(challengeFile) then
    local file = fs.open(challengeFile, "r")
    local target = b64.decode(file.readAll())
    file.close()
    file = fs.open(challengeFile2, "r")
    local decoded = decode(file.readAll())
    file.close()
    if decoded ~= target then
      error("Incorrect encryption key")
    end
  else
    local target = tostring(chacha.genNonce(32))
    local encoded = encode(target)
    local file = fs.open(challengeFile2, "w")
    file.write(encoded)
    file.close()
    file = fs.open(challengeFile, "w")
    file.write(b64.encode(target))
    file.close()
  end
  
  function encfs.exists(fs, path, ...)
    local path = fs.combine(location, path)
    if path == noncefile then
      return false
    else
      return fs.exists(path)
    end
  end

  function encfs.list(fs, path, ...)
    local path = fs.combine(location, path)
    local files = fs.list(path)
    if path ~= location then
      return files
    end
    local files2 = {}
    for _, v in pairs(files) do
      if v ~= ".nonce" then
        files2[#files2 + 1] = v
      end
    end
    return files2
  end

  copy("getSize")
  copy("isDir")
  copy("isReadOnly")
  copy("makeDir")

  function encfs.delete(fs, path, ...)
    local path = fs.combine(location, path)
    
    if path == noncefile then
      error("File does not exist")
    end
    return fs.delete(path)
  end

  function encfs.open(fs, path, mode)
    local newpath = fs.combine(location, path)

    if newpath == noncefile then
      error("File cannot be touched")
    end

    if mode == "r" or mode == "rb" then
      local file = fs.open(newpath, "r")
      local reader = stringReader(decode(file.readAll()))
      file.close()
      return reader
    else
      if fs.exists(newpath) and fs.isDir(newpath) then
        error("Is not a file but a directory")
      end
      local start = ""
      if mode == "a" and fs.exists(newpath) then
        local file = fs.open(newpath, "r")
        start = file.readAll()
        file.close()
      end
      function onFlush(text)
        local file = fs.open(newpath, "w")
        file.write(encode(text))
        file.close()
      end
      return stringWriter(start, onFlush)
    end
  end
  copy("getDrive")
  copy("getFreeSpace")
  copy("getName")
  copy("getDir")
  copy("isDriveRoot")
  copy("getCapacity")
  copy("attributes")


  function encfs.find(fs, path, ...)
    local path = fs.combine(location, path)
    local files = fs.find(path, ...)
    local files2 = {}
    for _, v in pairs(files) do
      if v:find(".nonce") == nil then
        files2[#files2 + 1] = v
      end
    end
    return files2
  end

  function encfs.copy(fs, a, b)
    local a, b = fs.combine(location, a), fs.combine(location, b)
    if a == noncefile or b == noncefile then
      error("Cannot touch file")
    end

    return fs.copy(a, b)
  end

  function encfs.move(fs, a, b)
    local a, b = fs.combine(location, a), fs.combine(location, b)
    if a == noncefile or b == noncefile then
      error("Cannot touch file")
    end

    return fs.move(a, b)
  end

  function encfs.moveOut(fs, a, b)
    local a = fs.combine(location, a)
    if a == noncefile then
      error("Cannot touch file")
    end

    return fs.move(a, b)
  end

  function encfs.moveIn(fs, a, b)
    local b = fs.combine(location, b)
    if b == noncefile then
      error("Cannot touch file")
    end

    return fs.move(a, b)
  end

  fs.mount(location, encfs)
end
