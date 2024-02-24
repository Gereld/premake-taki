--
-- taki.lua
-- (c) 2016-2017 Jason Perkins, Blizzard Entertainment and the Premake project
--

	local p 		= premake
	local project 	= p.project

	local config     = p.config
	local fileconfig = p.fileconfig

	p.modules.taki = {}
	p.modules.taki._VERSION = p._VERSION
	local taki = p.modules.taki

	local option = p.option
	local opt = table.deepcopy(option.list["cc"])
	table.insert(opt.allowed, { "msc", "Microsoft toolset" })
	option.add(opt)

	local u = dofile("utility.lua")

--
-- Comment.
--

	function taki.generateWorkspace(wks, generator)
		generator.generateWorkspace(wks)
	end

	
	function taki.generateProject(prj, generator, kind)
		kind.generateProject(prj)

		generator.generateProject(prj)

		-- allow the garbage collector to clean things up.
		for cfg in project.eachconfig(prj) do
			cfg._taki = nil
		end
		prj._taki = nil
	end

--
-- Format a list of values to be safely written as part of a variable assignment.
--

	function taki.list(value, quoted)
		--todo 2023.12.17 : quoted
		--quoted = false
		if #value > 0 then
			if quoted then
				local result = ""
				for _, v in ipairs (value) do
					if #result then
						result = result .. " "
					end
					result = result .. p.quoted(v)
				end
				return result
			else
				--return " " .. table.concat(value, " ")
				return table.concat(value, " ")
			end
		else
			return ""
		end
	end


	function taki.esc(value)
		value = value:gsub("%$", "$$")
		value = value:gsub(":", "$:")
		value = value:gsub("\n", "$\n")
		value = value:gsub(" ", "$ ")
		return value
	end
	
--
-- Convert an arbitrary string (project name) to a make variable name.
--

	function taki.tovar(value)
		value = value:gsub("[ -]", "_")
		value = value:gsub("[()]", "")
		return value
	end


	local map = u.map
	taki.map = u.map


	function taki.startsWith(where, what)
		return where:sub(1, #what) == what
	end


	function taki.replaceStart(where, what, with)
		if taki.startsWith(where, what) then
			return with .. where:sub(#what + 1, #where)
		else 
			return where
		end
	end


	function taki.alias(cfg, files)
		cfg._taki.alias = cfg._taki.alias or {
			targetdir	= project.getrelative(cfg.project, cfg.buildtarget.directory),
			target 		= path.join('%{TARGETDIR}', cfg.buildtarget.name),
			objdir		= project.getrelative(cfg.project, cfg.objdir),
		}
		local alias = cfg._taki.alias

		local function action(file)
			file = project.getrelative(cfg.project, file)
			file = taki.replaceStart(file, alias.targetdir, '%{TARGETDIR}')
			file = taki.replaceStart(file, alias.target, '%{TARGET}')
			file = taki.replaceStart(file, alias.objdir, '%{OBJDIR}')		
			return file
		end

		if type(files) == 'table' then
			return u.mapTable(files, action)
		else
			return action(files)
		end
	end


	function taki.path(cfg, files)
		local function action(file)
			file = project.getrelative(cfg.project, file)
			file = taki.esc(file)
			return file
		end

		if type(files) == 'table' then
			files = u.mapTable(files, action)
			files = table.filterempty(files)
			return files
		else
			return action(files)
		end
	end


	function taki.variable(variables, name, value)
		variables.table = variables.table or {}
		variables.keys = variables.keys or {}

		variables.table[name] = value
		table.insert(variables.keys, name)
	end


	function taki.getToolSet(cfg)
		local default = "gcc"
		default = iif(cfg.system == p.MACOSX, "clang", default)
		default = iif(cfg.system == p.WINDOWS, "msc", default)
		local toolset = p.tools[_OPTIONS.cc or cfg.toolset or default]
		if not toolset then
			error("Invalid toolset '" .. cfg.toolset .. "'")
		end
		return toolset
	end


	function taki.buildCmds(cfg, event)
		local steps = nil
		local commands = cfg[event .. "commands"]
		if commands and #commands > 0 then
			local msg = cfg[event .. "message"]
			msg = msg or string.format("Running %s commands", event)
			steps = { '@echo ' .. msg }
			steps = table.join(steps, commands)
		end
		return steps
	end

    
	function taki.outputSection(prj, callback)
		local root = {}

		for cfg in project.eachconfig(prj) do
			-- identify the toolset used by this configurations (would be nicer if
			-- this were computed and stored with the configuration up front)

			local toolset = taki.getToolSet(cfg)

			local settings = {}
			local funcs = callback(cfg)
			for i = 1, #funcs do
				local c = p.capture(function ()
					funcs[i](cfg, toolset)
				end)
				if #c > 0 then
					table.insert(settings, c)
				end
			end

			if not root.settings then
				root.settings = table.arraycopy(settings)
			else
				root.settings = table.intersect(root.settings, settings)
			end

			root[cfg] = settings
		end

		if #root.settings > 0 then
			for _, v in ipairs(root.settings) do
				p.outln(v)
			end
			--p.outln('')
		end

		local first = true
		for cfg in project.eachconfig(prj) do
			local settings = table.difference(root[cfg], root.settings)
			if #settings > 0 then
				--_p('')
				for k, v in ipairs(settings) do
					p.outln(v)
				end
			end
		end
	end


	-- convert a rule property into a string

	function taki.expandRuleString(rule, prop, value)
		-- list?
		if type(value) == "table" then
			if #value > 0 then
				if prop.switch then
					return prop.switch .. table.concat(value, " " .. prop.switch)
				else
					prop.separator = prop.separator or " "
					return table.concat(value, prop.separator)
				end
			else
				return nil
			end
		end

		-- bool just emits the switch
		if prop.switch and type(value) == "boolean" then
			if value then
				return prop.switch
			else
				return nil
			end
		end

		local switch = prop.switch or ""

		-- enum?
		if prop.values then
			value = table.findKeyByValue(prop.values, value)
			if value == nil then
				value = ""
			end
		end

		-- primitive
		value = tostring(value)
		if #value > 0 then
			return switch .. value
		else
			return nil
		end
	end


	function taki.prepareEnvironment(rule, environ, cfg)
		for _, prop in ipairs(rule.propertydefinition) do
			local fld = p.rule.getPropertyField(rule, prop)
			local value = cfg[fld.name]
			if value ~= nil then

				if fld.kind == "path" then
					value = taki.path(cfg, value)
				elseif fld.kind == "list:path" then
					value = taki.path(cfg, value)
				end

				value = taki.expandRuleString(rule, prop, value)
				if value ~= nil and #value > 0 then
					environ[prop.name] = p.esc(value)
				end
			end
		end
	end


	-----------------------------------------------------------------------------------------------


	function taki.createFileTable(prjLang, prj)
		for cfg in project.eachconfig(prj) do
			cfg._taki = cfg._taki or {}
			cfg._taki.filesets = cfg._taki.filesets or {}
			cfg._taki.fileRules = cfg._taki.fileRules or {}

			----log:write('cpp.pch -> prj._.files -> ' .. inspect(prj._.files, {depth = 1}) .. '\n')
			----log:write('cpp.pch -> cfg.files -> ' .. inspect(cfg.files, {depth = 1}) .. '\n')

			--local files = table.shallowcopy(prj._.files)
			--table.foreachi(files, function(node)
			--	taki.addFile(prjLang, cfg, node)
			--end)

			table.foreachi(cfg.files, function(filename)
				local node = prj._.files[filename]
				taki.addFile(prjLang, cfg, node)
			end)

			for _, f in pairs(cfg._taki.filesets) do
				table.sort(f)
			end

			cfg._taki.categories = table.keys(cfg._taki.filesets)
			table.sort(cfg._taki.categories)

			prj._taki.categories = table.join(prj._taki.categories or {}, cfg._taki.categories)
		end

		-- we need to reassign object sequences if we generated any files.
		if prj.hasGeneratedFiles and p.project.iscpp(prj) then
			p.oven.assignObjectSequences(prj)
		end

		prj._taki.categories = table.unique(prj._taki.categories)
		table.sort(prj._taki.categories)
	end


	function taki.addFile(prjLang, cfg, node)
		local filecfg = fileconfig.getconfig(node, cfg)
		if not filecfg or filecfg.flags.ExcludeFromBuild then
			return
		end

		-- skip generated files, since we try to figure it out manually below.
		if node.generated then
			return
		end

		if fileconfig.hasCustomBuildRule(filecfg) then
			-- process custom build commands.
			taki.addCustomBuildRuleFile(prjLang, cfg, node, filecfg)
		else
			-- process regular build commands.
			taki.addRuleFile(prjLang, cfg, node, filecfg)
		end
	end


	local function addRuleFiles(fileRules, prjLang, cfg, node)
		--log:write('taki.addRuleFiles -> rule ' .. inspect(fileRules, {depth = 2}) .. '\n')
		for _, fileRule in ipairs(fileRules) do
			table.insert(cfg._taki.fileRules, fileRule)

			for _, output in ipairs(fileRule.outputs) do
				taki.addGeneratedFile(prjLang, cfg, node, output)
			end
		end
	end
	
	
	function taki.addCustomBuildRuleFile(prjLang, cfg, node, filecfg)
		local environ = table.shallowcopy(filecfg.environ)
		environ.PathVars = {
			["file.basename"]     = { absolute = false, token = node.basename },
			["file.abspath"]      = { absolute = true,  token = node.abspath },
			["file.relpath"]      = { absolute = false, token = node.relpath },
			["file.name"]         = { absolute = false, token = node.name },
			["file.objname"]      = { absolute = false, token = node.objname },
			["file.path"]         = { absolute = true,  token = cfg, node.path },
			["file.directory"]    = { absolute = true,  token = path.getdirectory(node.abspath) },
			["file.reldirectory"] = { absolute = false, token = path.getdirectory(node.relpath) },
		}

		local shadowContext = p.context.extent(filecfg, environ)

		local buildoutputs = shadowContext.buildoutputs
		if not buildoutputs or #buildoutputs == 0 then
			return
		end

		local fileRule = {
			node			= node,

			inputs			= { node.abspath },
			outputs			= buildoutputs,
			dependencies	= shadowContext.buildinputs,

			message			= shadowContext.buildmessage,
			commands		= shadowContext.buildcommands,
		}
		
		addRuleFiles({fileRule}, prjLang, cfg, node)
	end


	function taki.addRuleFile(prjLang, cfg, node, filecfg)
		--log:write('\n')
		--log:write('taki.addRuleFile -> ' .. node.relpath .. '\n')

		local rules = cfg.project._taki.rules
		local fileext = prjLang.determineFiletype(cfg, node)
		local rule = rules[fileext]

		if not rule then
			return
		end

		local fileRule = prjLang.makeRuleFile(prjLang, cfg, node, filecfg, rule)
		addRuleFiles({fileRule}, prjLang, cfg, node)
	end


	function taki.addToFileset(cfg, categorie, filename)
		cfg._taki.filesets = cfg._taki.filesets or {}
		local fileset = cfg._taki.filesets[categorie] or {}
		table.insert(fileset, filename)
		cfg._taki.filesets[categorie] = fileset
	end


	function taki.addGeneratedFile(prjLang, cfg, source, filename)
		-- mark that we have generated files.
		cfg.project.hasGeneratedFiles = true

		-- add generated file to the project.
		local files = cfg.project._.files
		local node = files[filename]
		if not node then
			node = fileconfig.new(filename, cfg.project)
			files[filename] = node
			table.insert(files, node)
		end

		-- always overwrite the dependency information.
		node.dependsOn = source
		node.generated = true

		-- add to config if not already added.
		if not fileconfig.getconfig(node, cfg) then
			fileconfig.addconfig(node, cfg)
		end

		local categorie = prjLang.determineCategorie(cfg, node, source, filename)
		taki.addToFileset(cfg, categorie, filename)

		-- recursively setup rules.
		taki.addRuleFile(prjLang, cfg, node)
	end


	function taki.preBuildDependencies(cfg, dependencies)
		if not cfg.prebuildcommands or #cfg.prebuildcommands == 0 then
			return dependencies
		end

		local target = taki.per_cfg(cfg, cfg.project.name .. '_prebuild')

		return table.join( dependencies, { target } )
	end


	function taki.makeNormalRuleFile(prjLang, cfg, node, filecfg, rule)
		--log:write('taki.makeNormalRuleFile -> ' .. node.relpath .. '\n')
		local environ = table.shallowcopy(filecfg.environ)

		----log:write('taki.addRuleFile -> environ.file.path -> ' .. inspect(environ.file.path, {depth = 2}) .. '\n')
		----log:write('taki.addRuleFile -> environ.file -> ' .. inspect(rule.environ, {depth = 2}) .. '\n')

		local fcfgShadowContext = p.context.extent(filecfg, environ)
		fcfgShadowContext._basedir = cfg._basedir

		if rule.propertydefinition then
			taki.prepareEnvironment(rule, environ, cfg)
			taki.prepareEnvironment(rule, environ, filecfg)
		end

		local ruleShadowContext = p.context.extent(rule, environ)
		ruleShadowContext._basedir = cfg._basedir

		----log:write('taki.addRuleFile -> ruleShadowContext.buildcommands -> ' .. inspect(ruleShadowContext.buildcommands) .. '\n')

		local buildoutputs  = ruleShadowContext.buildoutputs
		local buildmessage  = ruleShadowContext.buildmessage
		local buildcommands = ruleShadowContext.buildcommands
		local buildinputs   = table.join(ruleShadowContext.buildinputs, fcfgShadowContext.buildinputs)
		local orderOnlyDependencies = taki.preBuildDependencies(cfg, {})

		buildoutputs = taki.alias(cfg,buildoutputs)
		--buildinputs = table.join(buildinputs, {'in1', 'in2'})
		--buildinputs = taki.alias(cfg, buildinputs)
		--orderOnlyDependencies = table.join(orderOnlyDependencies, {'hello', 'hela'})

		if not buildoutputs or #buildoutputs == 0 then
			return nil
		end

		local fileRule = {
			node			= node,
			rule			= rule,

			inputs			= { node.abspath },
			outputs			= buildoutputs,
			message			= buildmessage,
			implicitOutputs	= {},
			dependencies	= buildinputs,
			orderOnlyDependencies = orderOnlyDependencies,
		}

		return fileRule
	end


	function taki.processBinDirs(cfg, commands)
		--[[
			if cfg.bindirs and #cfg.bindirs > 0 then
				local dirs = taki.path(cfg, cfg.bindirs)
				if cfg.system == p.WINDOWS then
					table.insert(commands, 1, 'PATH=' .. table.concat(dirs, ';') .. ';%%PATH%%')
				else
					table.insert(commands, 1, 'PATH=' .. table.concat(dirs, ':') .. ':$$PATH')
				end
			end
		--]]
		return commands
	end


	-----------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------

	include("taki_cpp.lua")
	include("taki_csharp.lua")
	include("taki_makefile.lua")
	include("taki_utility.lua")
	include("taki_ninja.lua")
	include("_preload.lua")

	return taki
