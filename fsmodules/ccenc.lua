local ccenc = {}

function ccenc.encode(s)
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

function ccenc.decode(s)
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

return ccenc