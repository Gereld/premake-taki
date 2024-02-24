require("LuaPanda").start("127.0.0.1", 8818);

local utility = dofile "utility.lua"

local command = "cxx %{file.path} %{dimanche} $FLAGS"
print(command)

local context = {
  file = { path = "$in" },
  dimanche = "Dimanche",
}

print(utility.resolve(command, context))

local commands = { command, "link %{file.path} /O$out" }

local cmds = utility.map(commands, utility.resolve, context)
print(utility.dump(cmds))
