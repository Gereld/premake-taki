--
-- ninja_workspace.lua
-- Generate a workspace-level makefile.
-- (c) 2016-2017 Jason Perkins, Blizzard Entertainment and the Premake project
--

	local p 		= premake
	local taki 		= p.modules.taki

	local ninja 	= taki.ninja

	local tree  	= p.tree
	local project	= p.project

--
-- Generate a GNU make "workspace" makefile, with support for the new platforms API.
--

	function ninja.generateWorkspace(wks)
		p.eol("\n")

		ninja.header(wks)

		ninja.includeProjects(wks)

		ninja.configmap(wks)
		--[[
		ninja.projects(wks)

		ninja.workspacePhonyRule(wks)
		ninja.groupRules(wks)

		ninja.projectrules(wks)
		ninja.cleanRules(wks)
		ninja.helpRule(wks)
		--]]
		ninja.eof(wks)
	end

--
-- Write out the workspace's configuration map, which maps workspace
-- level configurations to the project level equivalents.
--

	--[[
	function ninja.outputFilename(cfg)
		return path.join(p.project.getrelative(cfg.workspace, cfg.buildtarget.directory), cfg.buildtarget.name)
	end
	--]]


	function ninja.configmap(wks)
		--[[
		local first = true
		for cfg in p.workspace.eachconfig(wks) do
			if first then
				_p('ifeq ($(config),%s)', cfg.shortname)
				first = false
			else
				_p('else ifeq ($(config),%s)', cfg.shortname)
			end

			for prj in p.workspace.eachproject(wks) do
				local prjcfg = project.getconfig(prj, cfg.buildcfg, cfg.platform)
				if prjcfg then
					_p('  %s_config = %s', ninja.tovar(prj.name), prjcfg.shortname)
				end
			end

			_p('')
		end

		if not first then
			_p('else')
			_p('  $(error "invalid configuration $(config)")')
			_p('endif')
			_p('')
		end
		--]]
		local function targetname(prj, cfg)
			return prj.name .. '_' .. cfg.shortname
		end

		_p('')
		_p('# Configurations ')
		_p('# #############################################')

		_p('')
		for cfg in p.workspace.eachconfig(wks) do
			local deps = {}
			for prj in p.workspace.eachproject(wks) do
				local prjcfg = project.getconfig(prj, cfg.buildcfg, cfg.platform)
				if prjcfg then
					table.insert(deps, targetname(prj, cfg))
				end
			end
			deps = taki.list(deps)

			_p('build %s: phony %s', cfg.shortname, deps)
		end

		for prj in p.workspace.eachproject(wks) do
			_p('')
			_p('# ' .. prj.name )
			_p('# #############################################')


			local dependencies = project.getdependencies(prj)
			--ninja.f:write(inspect(deps, { depth = 2 }))
			--deps = table.extract(deps, "name")
			--_p('%s:%s', p.esc(prj.name), ninja.list(deps))

			_p('')
			for cfg in p.project.eachconfig(prj) do
				local prjcfg = project.getconfig(prj, cfg.buildcfg, cfg.platform)
				if prjcfg then
					local deps = {}
					for _, prj in ipairs(dependencies) do
						table.insert(deps, targetname(prj, cfg))
					end
					deps = taki.list(deps)

					local prjMainTarget = cfg.project.name .. '_' .. ninja.per_cfg(cfg, 'ALL')

					--_p('build %s: phony %s%s', targetname(prj, cfg), ninja.outputFilename(cfg), strdeps)
					_p('build %s: phony %s %s', targetname(prj, cfg), prjMainTarget, deps)
				end
			end
		end

		_p('')
		_p('# #############################################')

		local configs = {}
		for cfg in p.workspace.eachconfig(wks) do
			table.insert(configs, cfg.shortname)
		end
		configs = taki.list(configs)

		_p('')
		_p('build all: phony %s', configs)

		--[[
		local firstcfg = nil
		for cfg in p.workspace.eachconfig(wks) do
			firstcfg = iif( not firstcfg, cfg.shortname, firstcfg)
		end	

		_p('default %s', firstcfg)
		_p('')
		--]]
		ninja.defaultConfig(wks)
	end

--
-- Write out the rules for the `make clean` action.
--

	function ninja.cleanRules(wks)
		_p('clean:')
		for prj in p.workspace.eachproject(wks) do
			local prjpath = p.filename(prj, ninja.getMakefileName(prj, true))
			local prjdir = path.getdirectory(path.getrelative(wks.location, prjpath))
			local prjname = path.getname(prjpath)
			_x(1,'@${MAKE} --no-print-directory -C %s -f %s clean', prjdir, prjname)
		end
		_p('')
	end

--
-- Write out the make file help rule and configurations list.
--

	function ninja.helpRule(wks)
		_p('help:')
		_p(1,'@echo "Usage: make [config=name] [target]"')
		_p(1,'@echo ""')
		_p(1,'@echo "CONFIGURATIONS:"')

		for cfg in p.workspace.eachconfig(wks) do
			_x(1, '@echo "  %s"', cfg.shortname)
		end

		_p(1,'@echo ""')

		_p(1,'@echo "TARGETS:"')
		_p(1,'@echo "   all (default)"')
		_p(1,'@echo "   clean"')

		for prj in p.workspace.eachproject(wks) do
			_p(1,'@echo "   %s"', prj.name)
		end

		_p(1,'@echo ""')
		_p(1,'@echo "For more information, see https://github.com/premake/premake-core/wiki"')
	end

--
-- Write out the list of projects that comprise the workspace.
--

	function ninja.projects(wks)
		_p('PROJECTS := %s', table.concat(p.esc(table.extract(wks.projects, "name")), " "))
		_p('')
	end

--
-- Write out the workspace PHONY rule
--

	function ninja.workspacePhonyRule(wks)
		local groups = {}
		local tr = p.workspace.grouptree(wks)
		tree.traverse(tr, {
			onbranch = function(n)
				table.insert(groups, n.path)
			end
		})

		_p('.PHONY: all clean help $(PROJECTS) ' .. table.implode(groups, '', '', ' '))
		_p('')
		_p('all: $(PROJECTS)')
		_p('')
	end

--
-- Write out the phony rules representing project groups
--

	function ninja.groupRules(wks)
		-- Transform workspace groups into target aggregate
		local tr = p.workspace.grouptree(wks)
		tree.traverse(tr, {
			onbranch = function(n)
				local rule = n.path .. ":"
				local projectTargets = {}
				local groupTargets = {}
				for i, c in pairs(n.children)
				do
					if type(i) == "string"
					then
						if c.project
						then
							table.insert(projectTargets, c.name)
						else
							table.insert(groupTargets, c.path)
						end
					end
				end
				if #groupTargets > 0 then
					table.sort(groupTargets)
					rule = rule .. " " .. table.concat(groupTargets, " ")
				end
				if #projectTargets > 0 then
					table.sort(projectTargets)
					rule = rule .. " " .. table.concat(projectTargets, " ")
				end
				_p(rule)
				_p('')
			end
		})
	end

--
-- Write out the rules to build each of the workspace's projects.
--

	function ninja.projectrules(wks)
		--[[
		for prj in p.workspace.eachproject(wks) do
			local deps = project.getdependencies(prj)
			deps = table.extract(deps, "name")
			_p('%s:%s', p.esc(prj.name), ninja.list(deps))

			local cfgvar = ninja.tovar(prj.name)
			_p('ifneq (,$(%s_config))', cfgvar)

			_p(1,'@echo "==== Building %s ($(%s_config)) ===="', prj.name, cfgvar)

			local prjpath = p.filename(prj, ninja.getMakefileName(prj, true))
			local prjdir = path.getdirectory(path.getrelative(wks.location, prjpath))
			local prjname = path.getname(prjpath)

			_x(1,'@${MAKE} --no-print-directory -C %s -f %s config=$(%s_config)', prjdir, prjname, cfgvar)

			_p('endif')
			_p('')
		end
		--]]
	end


	function ninja.includeProjects(wks)
		_p('')
		for prj in p.workspace.eachproject(wks) do
			local prjpath = p.filename(prj, ninja.getMakefileName(prj, true))
			local prjrelpath = path.getrelative(wks.location, prjpath)
			local prjdir = path.getdirectory(prjrelpath)
			local prjname = path.getname(prjpath)

			_p('subninja ' .. prjrelpath)
		end
	end

--
-- Write out the default configuration rule for a workspace or project.
--
-- @param target
--    The workspace or project object for which a makefile is being generated.
--

	function ninja.defaultConfig(target)
		_p('')
		_p('# Default target')
		_p('# #############################################')

		-- find the right configuration iterator function for this object
		local eachconfig = iif(target.project, project.eachconfig, p.workspace.eachconfig)
		local defaultconfig = nil

		-- find the right default configuration platform, grab first configuration that matches
		if target.defaultplatform then
			for cfg in eachconfig(target) do
				if cfg.platform == target.defaultplatform then
					defaultconfig = cfg
					break
				end
			end
		end

		-- grab the first configuration and write the block
		if not defaultconfig then
			local iter = eachconfig(target)
			defaultconfig = iter()
		end

		_p('')
		_p('default %s', defaultconfig.shortname)

		--[[
		if defaultconfig then
			_p('ifndef config')
			_x('  config=%s', defaultconfig.shortname)
			_p('endif')
			_p('')
		end
		--]]
	end
