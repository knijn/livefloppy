local plugins = fs.list("disk/fsmodules")

for _, v in pairs(plugins) do
  shell.run(fs.combine("disk/fsmodules", v))
end

if not fs.exists("disk/sda") then
  fs.makeDir("disk/sda")
end


-- Set up disk encryption
do
  write("Pass: ")
  local pass = read("*")
  fs.encrypt("disk/sda", pass)
  fs.flatten("disk/sda")
end

-- Set up rom mapping
if not fs.exists("disk/sda/rom") then
  fs.makeDir("disk/sda/rom")
end
fs.symlink("disk/sda/rom", "rom")

-- Set drive as root partition
--fs.symlink("", "disk/sda")

if fs.exists("startup.lua")
  shell.run("startup.lua")
end




