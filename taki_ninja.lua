    local p		= premake
    local taki 	= p.modules.taki

    taki.ninja 	= {}
    local ninja = taki.ninja

    include("taki_ninja_workspace.lua")
	include("taki_ninja_project.lua")
