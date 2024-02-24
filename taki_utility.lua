--
-- taki_utility.lua
-- Generate a C/C++ project makefile.
-- (c) 2016-2017 Jason Perkins, Blizzard Entertainment and the Premake project
--

	local p 		 = premake
	local taki 		 = p.modules.taki

	taki.utility     = {}
	local utility    = taki.utility

	local project    = p.project
	local config     = p.config
	local fileconfig = p.fileconfig

---
-- Add namespace for element definition lists for premake.callarray()
---

	utility.elements = {}

--
-- Generate a GNU make utility project makefile
--

	utility.elements.initialize = function(prj)
		return {
			utility.initializeProject,
			function(prj) taki.createFileTable(utility, prj) end,
		}
	end


	function utility.generateProject(prj)
		p.callArray(utility.elements.initialize, prj)
	end


	function utility.initializeProject(prj)
		prj._taki = prj._taki or {}
		prj._taki.rules = prj.rules
		prj._taki.filesets = {}
	end


	function utility.determineFiletype(cfg, node)
		return path.getextension(node.abspath):lower()
	end


	function utility.determineCategorie(cfg, node, source, filename)
		return "CUSTOM"
	end

	--[[
	function utility.bindirs(cfg, toolset)
		local dirs = project.getrelative(cfg.project, cfg.bindirs)
		if #dirs > 0 then
			p.outln('EXECUTABLE_PATHS = "' .. table.concat(dirs, ":") .. '"')
		end
	end


	function utility.exepaths(cfg, toolset)
		local dirs = project.getrelative(cfg.project, cfg.bindirs)
		if #dirs > 0 then
			p.outln('EXE_PATHS = PATH=$(EXECUTABLE_PATHS):$$PATH;')
		end
	end
	--]]


	--[[
	function utility.outputFileRules(cfg, file)
		local outputs = table.concat(file.buildoutputs, ' ')

		local dependencies = p.esc(file.source)
		if file.buildinputs and #file.buildinputs > 0 then
			dependencies = dependencies .. ' ' .. table.concat(p.esc(file.buildinputs), ' ')
		end

		_p('%s: %s', outputs, dependencies)

		if file.buildmessage then
			_p('\t@echo %s', file.buildmessage)
		end

		if file.buildcommands then
			local cmds = os.translateCommandsAndPaths(file.buildcommands, cfg.project.basedir, cfg.project.location)
			for _, cmd in ipairs(cmds) do
				if cfg.bindirs and #cfg.bindirs > 0 then
					_p('\t$(SILENT) $(EXE_PATHS) %s', cmd)
				else
					_p('\t$(SILENT) %s', cmd)
				end
			end
		end
	end
	--]]