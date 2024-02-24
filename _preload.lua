--
-- Name:        taki/_preload.lua
-- Purpose:     Define the taki action.
-- Author:      Blizzard Entertainment (Tom van Dijck)
-- Modified by: Aleksi Juvani
--              Vlad Ivanov
-- Created:     2016/01/01
-- Copyright:   (c) 2016-2017 Jason Perkins, Blizzard Entertainment and the Premake project
--

	local p = premake
	local project = p.project

	newaction {
		trigger         = "ninja",
		shortname       = "ninja",
		description     = "Ninja is a small build system with a focus on speed (v2)",
		toolset         = "gcc",

		valid_kinds     = { "ConsoleApp", "WindowedApp", "StaticLib", "SharedLib", "Utility", "Makefile" },

		valid_languages = { "C", "C++", "C#" },

		valid_tools     = {
			cc     = { "clang", "gcc", "msc" },
			dotnet = { "mono", "msnet", "pnet" }
		},

		onInitialize = function()
			require("taki")
			p.modules.taki.cpp.initialize()
		end,

		onWorkspace = function(wks)
			p.escaper(p.modules.taki.esc)
			local taki = p.modules.taki 
			local generator = taki['ninja']
			p.generate(wks, generator.getMakefileName(wks, false), function(wks) taki.generateWorkspace(wks, generator) end)
		end,

		onProject = function(prj)
			p.escaper(p.modules.taki.esc)
			local taki = p.modules.taki
			local generator = taki['ninja']
			local makefile = generator.getMakefileName(prj, true)

			local kind = nil
			if prj.kind == p.UTILITY then
				kind = taki.utility
			elseif prj.kind == p.MAKEFILE then
				kind = taki.makefile
			else
				if project.isdotnet(prj) then
					kind = taki.cs
				elseif project.isc(prj) or project.iscpp(prj) then
					kind = taki.cpp
				end
			end

			if kind then
				p.generate(prj, makefile, function(prj) taki.generateProject(prj, generator, kind) end)
			end
		end,

		onCleanWorkspace = function(wks)
			local generator = p.modules.taki['ninja']
			p.clean.file(wks, generator.getMakefileName(wks, false))
		end,

		onCleanProject = function(prj)
			local generator = p.modules.taki['ninja']
			p.clean.file(prj, generator.getMakefileName(prj, true))
		end
	}

--
-- Decide when the full module should be loaded.
--

	return function(cfg)
		return (_ACTION == "ninja")
	end
