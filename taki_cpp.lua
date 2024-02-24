--
-- ninja_cpp.lua
-- Generate a C/C++ project makefile.
-- (c) 2016-2017 Jason Perkins, Blizzard Entertainment and the Premake project
--

	local p 		 = premake
	local taki 		 = p.modules.taki

	taki.cpp         = {}
	local cpp        = taki.cpp

	local project    = p.project
	local config     = p.config
	local fileconfig = p.fileconfig

	local u = require "utility"

	--  -D_MT -Xclang --dependent-lib=libcmtd


---
-- Add namespace for element definition lists for premake.callarray()
---

	cpp.elements = {}

--
-- Generate a GNU make C++ project makefile, with support for the new platforms API.
--

	cpp.elements.initialize = function(prj)
		return {
			cpp.initializeProject,
			cpp.initializeConfigurations,
			--cpp.computePerFileConfiguration,
			function(prj) taki.createFileTable(cpp, prj) end,
			cpp.createMoreTargets,
		}
	end


	function cpp.generateProject(prj)
		p.callArray(cpp.elements.initialize, prj)
	end

	
	function cpp.determineFiletype(cfg, node)
		-- determine which filetype to use
		local filecfg = fileconfig.getconfig(node, cfg)
		local fileext = path.getextension(node.abspath):lower()
		if filecfg and filecfg.compileas then
			if p.languages.isc(filecfg.compileas) then
				fileext = ".c"
			elseif p.languages.iscpp(filecfg.compileas) then
				fileext = ".cpp"
			end
		end

		return fileext
	end


	function cpp.determineCategorie(cfg, node, source, filename)
		-- determine which filetype to use
		local fileext = cpp.determineFiletype(cfg, node)
		-- add file to the fileset.
		local ext_to_categorie = cfg.project._taki.ext_to_categorie
		local categorie = ext_to_categorie[fileext] or "CUSTOM"

		-- don't link generated object files automatically if it's explicitly
		-- disabled.
		if path.isobjectfile(filename) and source.linkbuildoutputs == false then
			categorie = "CUSTOM"
		end

		return categorie
	end


	cpp.gcc_default_tools = {
		cc = "$CC",
		cxx = "$CXX",
		ar = "$AR",
		rc = "windres"
	}

	local function getToolName(cfg, toolset, tool)
		if tool == 'link' then
			tool = iif(cfg.language == "C", "cc", "cxx")
		end
		return toolset.gettoolname(cfg, tool)
		--[[
		if name then
			return name
		else
			name = iif( toolset._taki.basename == 'gcc', cpp.gcc_default_tools[tool], name)
			name = iif( (toolset._taki.basename == 'gcc') and (cfg.system == p.WINDOWS), p.tools.gcc.tools[tool], name) --todo-tmp
			return name
		end
		--]]
	end


	function cpp.initialize()
		log:write('premake.path -> ' .. p.path .. '\n')
		log:write('os.target() -> ' .. inspect(_OPTIONS, {depth = 3}) .. '\n')

		for k, toolset in pairs(p.tools) do
			if type(toolset) == "table" then
				toolset._taki = toolset._taki or {}
				local _taki = toolset._taki

				local name = string.format("%s", k)
				_taki.name = name
				if taki.startsWith(name, "clang") then
					_taki.basename = "clang"
				elseif taki.startsWith(name, "gcc") then
					_taki.basename = "gcc"
				elseif taki.startsWith(name, "msc") then
					_taki.basename = "msc"
				elseif taki.startsWith(name, "mingw") then
					_taki.basename = "gcc"
				else
					_taki.basename = name
				end
			end
		end

		--[[
		rule 'cxx'
			fileExtension { '.cc', '.cpp', '.cxx', '.mm' }
			buildoutputs  { '%{cfg.objdir}/%{file.objname}.o' }
			buildcommands { 'cxx %{file.path}' }

		rule 'cc'
			fileExtension { '.c', '.s', '.m' }
			buildoutputs  { '%{cfg.objdir}/%{file.objname}.o' }
			buildcommands { 'cc %{file.path}' }

		rule 'resource'
			fileExtension '.rc'
			buildoutputs  { '%{cfg.objdir}/%{file.objname}.res' }
			buildcommands { 'rc %{file.path}' }
		--]]
		rule 'special_rule_cxx'
			fileExtension { '.cc', '.cpp', '.cxx', '.mm' }
			buildoutputs  { '%{file.objname}.o' }
			buildcommands { 'cxx' }
			buildmessage  'object'

		rule 'special_rule_cc'
			fileExtension { '.c', '.s', '.m' }
			buildoutputs  { '%{file.objname}.o' }
			buildcommands { 'cc' }
			buildmessage  'object'

		rule 'special_rule_resource'
			fileExtension { '.rc' }
			buildoutputs  { '%{file.objname}.res' }
			buildcommands { 'rc' }
			buildmessage  'resources'

		rule 'special_rule_link'
			buildoutputs  { '%{file.objname}.exe' }
			buildcommands { 'link' }
			buildmessage  'link'
		
		rule 'special_rule_ar'
			buildoutputs  { '%{file.objname}.lib' }
			buildcommands { 'ar' }
			buildmessage  'ar'

		global(nil)

		-- mark the rules above as internal for custom processing
		cpp.internalRules = {
			special_rule_cxx = {
				name = 'cxx',
				categorie = 'object',
				language = 'CXX',
			},
			special_rule_cc = {
				name = 'cc',
				categorie = 'object',
				language = 'C',
			},
			special_rule_resource = {
				name = 'rc',
				categorie = 'resources',
			},
			special_rule_link = {
				name = 'link',
				categorie = 'exe',
			},
			special_rule_ar = {
				name = 'ar',
				categorie = 'lib',
			},
		}

		-- patch msc toolset for not providing tool names.
		--[[
 		local compiler = p.tools.msc.gettoolname(nil, 'cxx')
		if not compiler then
			p.tools.msc.tools = {
				cc ='cl',
				cxx = 'cl',
				ar = 'lib',
				rc = 'rc',
			}

			p.tools.msc.gettoolname = function(cfg, tool)
				return p.tools.msc.tools[tool]
			end
		end
		--]]

		p.tools.msc._taki = p.tools.msc._taki or {}
		p.tools.msc._taki.getToolName = p.tools.msc.gettoolname
		p.tools.msc.gettoolname = function(cfg, tool)
			local name = p.tools.msc._taki.getToolName(cfg, tool)
			if name then
				return name
			end

			p.tools.msc.tools = {
				cc ='cl',
				cxx = 'cl',
				ar = 'lib',
				rc = 'rc',
			}

			p.tools.msc.gettoolname = function(cfg, tool)
				return p.tools.msc.tools[tool]
			end

			return p.tools.msc.gettoolname(cfg, tool)
		end 

		p.tools.gcc._taki = p.tools.gcc._taki or {}
		p.tools.gcc._taki.getToolName = p.tools.gcc.gettoolname
		p.tools.gcc.gettoolname = function(cfg, tool)
			local name = p.tools.gcc._taki.getToolName(cfg, tool)
			if name then
				return name
			end

			local _taki = p.tools.gcc._taki
			name = iif( _taki.basename == 'gcc', cpp.gcc_default_tools[tool], name)
			--todo: tmp
			name = iif( (_taki.basename == 'gcc') and (cfg.system == p.WINDOWS), p.tools.gcc.tools[tool], name) 

			return name
		end

		p.tools.clang._taki = p.tools.clang._taki or {}
		p.tools.clang._taki.getToolName = p.tools.clang.gettoolname
		p.tools.clang.gettoolname = function(cfg, tool)
			local name = p.tools.clang._taki.getToolName(cfg, tool)
			if name then
				return name 
			end

			if tool == 'rc' then
				return 'windres'
			end

			return nil
		end

		cpp.toolsets = {
			['msc'] = {},
			['clang'] = {},
			['gcc'] = {},
		}
		local toolsets = cpp.toolsets
		local msc = toolsets['msc']
		local clang = toolsets['clang']
		local gcc = toolsets['gcc']

		msc.extensions = {
			['object'] = '.obj',
			['lib'] = '.lib',
			['dll'] = '.dll',
			['exe'] = '.exe',
			['resources'] = '.res',
			['pch'] = '.pch'
		}
		clang.extensions = {
			['object'] = '.o',
			['lib'] = '.a',
			['dll'] = '.so',
			['exe'] = '',
			['resources'] = '.res',
			['pch'] = '.gch'
		}
		--gcc.extensions = clang.extensions
		gcc.extensions = {
			['object'] = '.o',
			['lib'] = '.a',
			['dll'] = '.so',
			['exe'] = '',
			['resources'] = '.res',
			['pch'] = '.gch'
		}

		local mscCompile = { parameters = ' %{FLAGS} %{PCH} /showIncludes /nologo /Fo%{out} /c %{in}', deps = 'msvc' }
		msc.rules = {
			['cxx']		= mscCompile,
			['cc']		= mscCompile,
			['ar']		= { parameters = ' %{in} /nologo %{FLAGS} /out:%{out}' },
			['rc']		= { parameters = ' /nologo /fo%{out} %{in}' },
			['link']	= { parameters = ' %{in} %{LIBS} /link /nologo %{FLAGS} /out:%{out}' },
		}

		local clangCompile = { parameters = ' %{PCH} %{FLAGS} -MF %{out}.d -o %{out} -c %{in}', deps = 'gcc', depfile = '%{out}.d' }
		clang.rules = {
			['cxx'] 	= clangCompile,
			['cc'] 		= clangCompile,
			['ar'] 		= { parameters = ' -rcs %{out} %{in}' },
			['rc'] 		= { parameters = ' %{in} -O coff -o %{out}' },
			['link'] 	= { parameters = ' %{in} %{LIBS} %{FLAGS} -o %{out}' },
		}

		gcc.rules = clang.rules

		msc.defaultlibs = ' kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib'
	end


	function cpp.initializeProject(prj)
		local rules = {}

		-- add all rules.
		local usedRules = table.join(table.keys(cpp.internalRules), prj.rules)
		for _, name in ipairs(usedRules) do
			local rule = p.global.getRule(name)
			taki.map(rule.fileExtension, function(extension) rules[extension] = rule end)
		end

		----log:write('prj.rules = ' .. inspect(usedRules, {depth = 3}) .. '\n')

		-- create fileset categories.
		local ext_to_categorie = {
			['.o']    = 'OBJECTS',
			['.obj']  = 'OBJECTS',
			['.cc']   = 'SOURCES',
			['.cpp']  = 'SOURCES',
			['.cxx']  = 'SOURCES',
			['.mm']   = 'SOURCES',
			['.c']    = 'SOURCES',
			['.s']    = 'SOURCES',
			['.m']    = 'SOURCES',
			['.rc']   = 'RESOURCES',
			['.res']  = 'RESOURCES',
		}

		-- cache the result.
		prj._taki = prj._taki or {}
		prj._taki.rules = rules
		prj._taki.ext_to_categorie = ext_to_categorie
	end


	function cpp.initializeConfigurations(prj)
		for cfg in project.eachconfig(prj) do
			cpp.initializeConfiguration(cfg, taki.getToolSet(cfg))
		end
	end


	function cpp.initializeConfiguration(cfg, toolset)
		cfg._taki = cfg._taki or {}
		cfg._taki.filesets = cfg._taki.filesets or {}
		cfg._taki.fileRules = cfg._taki.fileRules or {}

		cfg._taki.template = cfg._taki.template or {
			variables = {
				table = {},
				keys = {},
			},
			rules = {},
			statements = {},
		}

		cpp.initializeRules(cfg, toolset)
		cpp.pch(cfg, toolset)
		cpp.initializeVariables(cfg, toolset)
	end

	
	function cpp.initializeRules(cfg, toolset)
		--log:write('cpp.initializeRules -> ' .. '*********************************************************************' .. '\n')

		local ts = cpp.toolsets[toolset._taki.basename]

		local usedRules = table.join(table.keys(cpp.internalRules), cfg.project.rules)
		table.sort(usedRules)
		--log:write('cpp.initializeRules -> ' .. inspect(usedRules) .. '\n')

		local templateRules = cfg._taki.template.rules

		local context = {
			file = { path = '%{in}', },
		}

		for i, ruleName in ipairs(usedRules) do
			local rule = p.global.getRule(ruleName)
			local internalRule = cpp.internalRules[ruleName]
			local name = ruleName
			local tool
			if internalRule then
				name = internalRule.name
				tool = getToolName(cfg, toolset, name)
			end
			
			--local ruleShadowContext = p.context.extent(rule, environ)
			----log:write('cpp.initializeRules -> ' .. inspect(rule.current, {depth = 2}) .. '\n')

			local outputs = rule.current.buildoutputs
			outputs = taki.map(outputs, function(str)
				str = str:gsub(rule.current.basedir .. '\a', '')
				return str
			end)

			local commands = rule.current.buildcommands
			if tool then
				commands = { tool .. ts.rules[name].parameters }
			end
	
			if name == 'link' then
				--[[ +yin+2024.02.20
				local prelinkcommands = taki.buildCmds(cfg, 'prelink') or {}
				local postbuildcommands = taki.buildCmds(cfg, 'postbuild') or {}
				--]]
				local prelinkcommands = iif(taki.buildCmds(cfg, 'prelink'), { "%{PRE_LINK_COMMANDS}" }, {})
				local postbuildcommands = iif(taki.buildCmds(cfg, 'postbuild'), { "%{POST_BUILD_COMMANDS}" }, {})

				commands = table.join(prelinkcommands, commands, postbuildcommands)
			end

			local function replaceOutputsWithVariables(str)
				for i, k in ipairs(outputs) do
					k = k:gsub('%%', '%%%%')
					local id = iif(i == 1, '', tostring(i - 1))
					str = str:gsub(k, '%%{out' .. id .. '}')
				end
				return str 
			end
			commands = taki.map(commands, replaceOutputsWithVariables)
			commands = taki.map(commands, u.resolve, context)

			local cfgRule = {
				name = name,
				used = false,
				commands = commands,
				outputs = outputs,
				-- deps
				-- depfile
				-- message
			}

			if tool then
				if ts.rules[name].deps then 
					cfgRule.deps = ts.rules[name].deps
				end

				if ts.rules[name].depfile then 
					cfgRule.depfile = ts.rules[name].depfile
				end
			end

			--log:write('cpp.initializeRules -> ' .. inspect(cfgRule, {depth = 2}) .. '\n')

			templateRules[ruleName] = cfgRule
		end

		--log:write('cpp.initializeRules -> ' .. inspect(cfg._taki.template.rules, {depth = 2}) .. '\n')
		-- custom
	end
	

	function cpp.initializeVariables(cfg, toolset)
		local variables = cfg._taki.template.variables

		local function add(name, value)
			taki.variable(variables, name, value)
		end

		add('TARGETDIR', project.getrelative(cfg.project, cfg.buildtarget.directory))
		add('TARGET', path.join('%{TARGETDIR}', cfg.buildtarget.name))
		add('OBJDIR', project.getrelative(cfg.project, cfg.objdir))
	
		local defines = table.join(toolset.getdefines(cfg.defines, cfg), toolset.getundefines(cfg.undefines))
		defines = table.unique(defines)
		add('DEFINES', taki.list(defines))

		--local includes = toolset.getincludedirs(cfg, cfg.includedirs, cfg.sysincludedirs, cfg.externalincludedirs)
		local includes = toolset.getincludedirs(cfg, cfg.includedirs, cfg.externalincludedirs, cfg.frameworkdirs)
		add('INCLUDES', taki.list(includes))

		local includes = toolset.getforceincludes(cfg)
		add('FORCE_INCLUDE', taki.list(includes))

		local flags = taki.list(toolset.getcppflags(cfg))
		add('ALL_CPPFLAGS', '$CPPFLAGS %{FORCE_INCLUDE} %{DEFINES} %{INCLUDES} ' .. flags)

		local flags = taki.list(table.join(toolset.getcflags(cfg), cfg.buildoptions))
		add('ALL_CFLAGS', '%{ALL_CPPFLAGS} $CFLAGS ' .. flags)

		local flags = taki.list(table.join(toolset.getcxxflags(cfg), cfg.buildoptions))
		add('ALL_CXXFLAGS', '%{ALL_CPPFLAGS} $CXXFLAGS ' .. flags)

		local resflags = table.join(toolset.getdefines(cfg.resdefines), toolset.getincludedirs(cfg, cfg.resincludedirs), cfg.resoptions)
		add('ALL_RESFLAGS', '$RESFLAGS %{DEFINES} %{INCLUDES} ' .. taki.list(resflags))

		local defaultlibs = cpp.toolsets[toolset._taki.basename].defaultlibs
		defaultlibs = iif(defaultlibs, defaultlibs, '')
		local flags = toolset.getlinks(cfg)
		add('LIBS', taki.list(flags, true) .. defaultlibs)

		local deps = config.getlinks(cfg, "siblings", "fullpath")
		add('LDDEPS', taki.list(p.esc(deps)))

		local flags = table.join(toolset.getLibraryDirectories(cfg), toolset.getrunpathdirs(cfg, cfg.runpathdirs), toolset.getldflags(cfg), cfg.linkoptions)
		add('ALL_LDFLAGS', '$LDFLAGS ' .. taki.list(flags))
	end


	function cpp.pch(cfg, toolset)
		cfg._taki.pch = cfg._taki.pch or {}

		local pch = cfg._taki.pch
		pch.uses = false 

		-- If there is no header, or if PCH has been disabled, I can early out
		if not cfg.pchheader or cfg.flags.NoPCH then
			return
		end

		pch.uses = true

		-- Visual Studio requires the PCH header to be specified in the same way
		-- it appears in the #include statements used in the source code; the PCH
		-- source actual handles the compilation of the header. GCC compiles the
		-- header file directly, and needs the file's actual file system path in
		-- order to locate it.

		-- To maximize the compatibility between the two approaches, see if I can
		-- locate the specified PCH header on one of the include file search paths
		-- and, if so, adjust the path automatically so the user doesn't have
		-- add a conditional configuration to the project script.

		local pchheader = cfg.pchheader
		local found = false

		-- test locally in the project folder first (this is the most likely location)
		local testname = path.join(cfg.project.basedir, pchheader)
		if os.isfile(testname) then
			pchheader = project.getrelative(cfg.project, testname)
			found = true
		else
			-- else scan in all include dirs.
			for _, incdir in ipairs(cfg.includedirs) do
				testname = path.join(incdir, pchheader)
				if os.isfile(testname) then
					pchheader = project.getrelative(cfg.project, testname)
					found = true
					break
				end
			end
		end

		if not found then
			pchheader = project.getrelative(cfg.project, path.getabsolute(pchheader))
		end

		pch.header = pchheader
		pch.source = ''
		pch.output = ''
		pch.useflags = ''
		pch.createflags = ''

		local is_c_project = project.isc(cfg.project)
		pch.command = iif(is_c_project, "cc", "cxx")
		pch.language = iif(is_c_project, "C", "CXX")

		--local objdir = project.getrelative(cfg.project, cfg.objdir)
		local objdir = cfg.objdir
		--local objdir = '%{OBJDIR}'

		----log:write('cpp.pch\n')
		----log:write(inspect(cfg, {depth = 2}) .. '\n')

		if toolset._taki.basename == 'msc' then
			pch.source = cfg.pchsource
			pch.output = path.join(objdir, path.replaceextension(cfg.pchheader, ".obj"))

			-- add this generated pch obj to the link inputs
			taki.addToFileset(cfg, 'OBJECTS', pch.output)

			local pchFile = taki.alias(cfg, path.join(objdir, path.replaceextension(cfg.pchheader, ".pch")))
			local pchHeader = cfg.pchheader
			pch.createflags = ' /Yc"' .. pchHeader .. '"' .. ' /Fp"' .. pchFile .. '"'
			pch.useflags = ' /Yu"' .. pchHeader .. '"' .. ' /FI"' .. pchHeader .. '"' .. ' /Fp"' .. pchFile .. '"'
			pch.dependencies = pchHeader
		elseif toolset._taki.basename == 'clang' then
			pch.source = pch.header
			pch.output = path.join(objdir, path.replaceextension(cfg.pchheader, ".gch"))

			if is_c_project then 
				pch.createflags = '-x c-header'
			else		
				pch.createflags = '-x c++-header'
			end	
			--pch.createflags = ' -emit-pch'
			local pchOutput = taki.alias(cfg, pch.output)
			pch.useflags = '-include-pch ' .. pchOutput
		elseif toolset._taki.basename == 'gcc' then
			--pch.source = cfg.pchheader
			pch.source = pch.header
			--pch.output = path.join(objdir, path.replaceextension(cfg.pchheader, ".gch"))
			pch.output = path.join(objdir, cfg.pchheader .. ".gch")

			if is_c_project then 
				pch.createflags = '-x c-header'
			else		
				pch.createflags = '-x c++-header'
			end	
			local pchHeader = taki.alias(cfg, pch.source)
			local pchOutput = taki.alias(cfg, pch.output)
			pch.useflags = '-include ' .. pchHeader
			pch.useflags = '-I%{OBJDIR}'

			--pch.uses = false
		end

		-- remove the pch source from the fileRules list to prevent it from being processed twice
		if cfg.pchsource ~= '' then
			----log:write('pch.source ->' .. pch.source .. '\n')
			local found
			local files = cfg.files
			for i, filename in ipairs(files) do
				if filename == cfg.pchsource then
					----log:write('source ->' .. filename .. '\n')
					found = i
					break
				end	
			end

			if found then
				table.remove(files, found)
			end
		end
	end


	function cpp.createLinkTarget(cfg, toolset)
		if cfg.kind == p.UTILITY then
			return
		end

		local prj = cfg.project

		local objects = cfg._taki.filesets['OBJECTS']
		local resources = cfg._taki.filesets['RESOURCES']
		local inputs = table.join(objects, resources)
		inputs = taki.alias(cfg, inputs)

		local deps = config.getlinks(cfg, "siblings", "fullpath")
		local dependencies = taki.preBuildDependencies(cfg, deps)

		----log:write(inspect(items) .. '\n')
		----log:write(inspect(cfg._taki.filesets) .. '\n')

		local linkAction = ''
		if cfg.kind == p.STATICLIB then
			if cfg.architecture == p.UNIVERSAL then
				linkAction = 'libtool'
				--p.outln('LINKCMD = libtool -o "$@" $(OBJECTS)')
			else
				linkAction = 'ar'
				--p.outln('LINKCMD = $(AR) -rcs "$@" $(OBJECTS)')
			end
		else
			-- this was $(TARGET) $(LDFLAGS) $(OBJECTS)
			--   but had trouble linking to certain static libs; $(OBJECTS) moved up
			-- $(LDFLAGS) moved to end (http://sourceforge.net/p/premake/patches/107/)
			-- $(LIBS) moved to end (http://sourceforge.net/p/premake/bugs/279/)

			--local cc = iif(p.languages.isc(cfg.language), "CC", "CXX")
			--p.outln('LINKCMD = $(' .. cc .. ') -o "$@" $(OBJECTS) $(RESOURCES) $(ALL_LDFLAGS) $(LIBS)')
			linkAction = 'link'
		end

		local variables = {}
		taki.variable(variables, 'FLAGS', '%{ALL_LDFLAGS}' )
		taki.variable(variables, 'LIBS', '%{LIBS}')

		local ruleName = 'special_rule_' .. linkAction
		local rule = p.global.getRule(ruleName)

		local fileRule = {
			rule			= rule,
			name 			= cpp.internalRules[ruleName].name,

			inputs		  	= inputs,
			--outputs 		= { cfg.buildtarget.directory .. '/' .. cfg.buildtarget.name },					
			outputs 		= { '%{TARGET}' },			
			dependencies	= dependencies,
			variables		= variables,	
		}

		cfg._taki.template.main = fileRule
	end


	function cpp.createPchTarget(cfg, toolset)
		local pch = cfg._taki.pch
		if not pch.uses then
			return
		end

		local output = taki.alias(cfg, pch.output)
		local pchsource = taki.alias(cfg, pch.source)
		local dependencies = taki.preBuildDependencies(cfg, {})

		local variables = {}
		taki.variable(variables, 'FLAGS', '%{ALL_' .. pch.language .. 'FLAGS}')
		taki.variable(variables, 'PCH', pch.createflags)

		local ruleName = 'special_rule_' .. pch.command
		local rule = p.global.getRule(ruleName)

		local fileRule = {
			rule			= rule,
			name 			= cpp.internalRules[ruleName].name,

			inputs		  	= { pchsource },
			outputs 		= { output },			
			dependencies	= dependencies,
			variables		= variables,	
		}

		cfg._taki.template.pch = fileRule
	end


	function cpp.createMoreTargets(prj)
		for cfg in project.eachconfig(prj) do
			cpp.createPchTarget(cfg, taki.getToolSet(cfg))
			cpp.createLinkTarget(cfg, taki.getToolSet(cfg))
		end
	end
	
	--[[
	function cpp.linkCmd(cfg, toolset)
		if cfg.kind == p.STATICLIB then
			if cfg.architecture == p.UNIVERSAL then
				p.outln('LINKCMD = libtool -o "$@" $(OBJECTS)')
			else
				p.outln('LINKCMD = $(AR) -rcs "$@" $(OBJECTS)')
			end
		elseif cfg.kind == p.UTILITY then
			-- Empty LINKCMD for Utility (only custom build rules)
			p.outln('LINKCMD =')
		else
			-- this was $(TARGET) $(LDFLAGS) $(OBJECTS)
			--   but had trouble linking to certain static libs; $(OBJECTS) moved up
			-- $(LDFLAGS) moved to end (http://sourceforge.net/p/premake/patches/107/)
			-- $(LIBS) moved to end (http://sourceforge.net/p/premake/bugs/279/)

			local cc = iif(p.languages.isc(cfg.language), "CC", "CXX")
			p.outln('LINKCMD = $(' .. cc .. ') -o "$@" $(OBJECTS) $(RESOURCES) $(ALL_LDFLAGS) $(LIBS)')
		end
	end

	--]]


--
-- Write out the per file configurations.
--
	--[[
	function cpp.computePerFileConfiguration(prj)
		_p('# Per File Configurations')
		_p('# #############################################')
		_p('')
		for cfg in project.eachconfig(prj) do
			table.foreachi(prj._.files, function(node)
				local fcfg = fileconfig.getconfig(node, cfg)
				if fcfg then
					cpp.perFileFlags(cfg, fcfg)
				end
			end)
		end
		_p('')
		--]]

		--[[
		for cfg in project.eachconfig(prj) do
			table.foreachi(prj._.files, function(node)
				local fcfg = fileconfig.getconfig(node, cfg)
				if fcfg then
					local value = cpp.perFileFlags(cfg, fcfg)
					if value then
						fcfg.perFileFlags = value
					end
				end
			end)
		end
	end
	--]]

	--[[
	function cpp.makeVarName(prj, value, saltValue)
		prj._taki = prj._taki or {}
		prj._taki.varlist = prj._taki.varlist or {}
		prj._taki.varlistlength = prj._taki.varlistlength or 0
		local cache = prj._taki.varlist
		local length = prj._taki.varlistlength

		local key = value .. saltValue

		if (cache[key] ~= nil) then
			return cache[key], false
		end

		local var = string.format("PERFILE_FLAGS_%d", length)
		cache[key] = var

		prj._taki.varlistlength = length + 1

		return var, true
	end
	--]]

	local function display(object)
		for k, value in pairs(object) do
			--log:write(tostring(k) .. '\n')
		end
	end


	local function commonKeys(object, other)
		local t = {}
		for k, v in pairs(object) do
			if other[k] then
				table.insert(t, k)
			end
		end
		return t
	end


	local function copyOrMergeValues(dst, src, keys)
		for _, key in ipairs(keys) do
			if type(dst[key]) == 'table' then
				dst[key] = table.join(dst[key], src[key])
			else
				dst[key] = src[key]
			end
		end
		return dst
	end


	function cpp.perFileFlags(cfg, fcfg)
		----log:write(fcfg.name .. '\n\n')
		--if fcfg.name == 'atlbase.cpp' then
			----log:write(inspect(getmetatable(fcfg), { depth = 3 }) .. '\n\n')
			--display(fcfg)
		--end

		local keys = commonKeys(cfg, fcfg)
		----log:write(inspect(keys, { depth = 3 }) .. '\n\n')

		keys = table.filter(keys, function(key) return #fcfg[key] > 0 end)
		keys = table.filter(keys, function(key) 
			local str = tostring(key)
			return (str ~= '_basedir') and (str ~= 'name')
		end)

		--for k, v in ipairs(keys) do
		--	--log:write(tostring(v) .. ' = ' .. inspect(fcfg[v], { depth = 1 }) .. '\n')
		--end	

		if #keys == 0 then
			return nil
		end

		local tmpcfg = table.shallowcopy(cfg)
		copyOrMergeValues(tmpcfg, fcfg, keys)

		local toolset = taki.getToolSet(cfg)

		local isCFile = path.iscfile(fcfg.name)
		local getflags = iif(isCFile, toolset.getcflags, toolset.getcxxflags)
		local language = iif(isCFile, 'C', 'CXX')

		local defines = table.join(toolset.getdefines(tmpcfg.defines, tmpcfg), toolset.getundefines(tmpcfg.undefines))
		local includes = toolset.getincludedirs(tmpcfg, tmpcfg.includedirs, tmpcfg.sysincludedirs)
		local forceIncludes = toolset.getforceincludes(tmpcfg)
		local cppFlags = toolset.getcppflags(tmpcfg)
		local xFlags = table.join(getflags(tmpcfg), tmpcfg.buildoptions)

		local flags = table.join( {'%{CPPFLAGS}', '%{' .. language .. 'FLAGS}'}, includes, defines, forceIncludes, cppFlags, xFlags)

		----log:write('flags = ' .. inspect(flags) .. '\n')

		return flags
	end

	--[[
	function cpp.fileFlags(cfg, file)
		local fcfg = fileconfig.getconfig(file, cfg)
		local flags = {}

		if cfg.pchheader and not cfg.flags.NoPCH and (not fcfg or not fcfg.flags.NoPCH) then
			table.insert(flags, "-include $(PCH_PLACEHOLDER)")
		end

		if fcfg and fcfg.flagsVariable then
			table.insert(flags, string.format("$(%s)", fcfg.flagsVariable))
		else
			local fileExt = cpp.determineFiletype(cfg, file)

			if path.iscfile(fileExt) then
				table.insert(flags, "$(ALL_CFLAGS)")
			elseif path.iscppfile(fileExt) then
				table.insert(flags, "$(ALL_CXXFLAGS)")
			end
		end

		return table.concat(flags, ' ')
	end
	--]]

	--[[
	cpp.elements.rules = function(cfg)
		return {
			--cpp.allRules,
			--cpp.targetRules,
			--taki.targetDirRules,
			--taki.objDirRules,
			--cpp.cleanRules,
			--taki.preBuildRules,
			--cpp.customDeps,
			--cpp.pchRules,
		}
	end


	function cpp.outputRulesSection(prj)
		--_p('')
		--_p('# Rules')
		--_p('# #############################################')
		taki.outputSection(prj, cpp.elements.rules)
	end


	function cpp.allRules(cfg, toolset)
		if cfg.system == p.MACOSX and cfg.kind == p.WINDOWEDAPP then
			_p('all: $(TARGET) $(dir $(TARGETDIR))PkgInfo $(dir $(TARGETDIR))Info.plist')
			_p('\t@:')
			_p('')
			_p('$(dir $(TARGETDIR))PkgInfo:')
			_p('$(dir $(TARGETDIR))Info.plist:')
		else
			_p('all: $(TARGET)')
			_p('\t@:')
		end
		_p('')
	end


	function cpp.targetRules(cfg, toolset)
		local targets = ''

		for _, kind in ipairs(cfg._taki.kinds) do
			if kind ~= 'OBJECTS' and kind ~= 'RESOURCES' then
				targets = targets .. '$(' .. kind .. ') '
			end
		end

		targets = targets .. '$(OBJECTS) $(LDDEPS)'
		if cfg._taki.filesets['RESOURCES'] then
			targets = targets .. ' $(RESOURCES)'
		end

		_p('$(TARGET): %s | $(TARGETDIR)', targets)
		_p('\t$(PRELINKCMDS)')
		_p('\t@echo Linking %s', cfg.project.name)
		_p('\t$(SILENT) $(LINKCMD)')
		_p('\t$(POSTBUILDCMDS)')
		_p('')

		--_p('build $TARGET: link $OBJECTS')		
	end


	function cpp.customDeps(cfg, toolset)
		for _, categorie in ipairs(cfg._taki.categories) do
			if categorie == 'CUSTOM' or categorie == 'SOURCES' then
				_p('$(%s): | prebuild', categorie)
			end
		end
	end


	function cpp.pchRules(cfg, toolset)
		_p('ifneq (,$(PCH))')
		_p('$(OBJECTS): $(GCH) | $(PCH_PLACEHOLDER)')
		_p('$(GCH): $(PCH) | prebuild')
		_p('\t@echo $(notdir $<)')
		local cmd = iif(p.languages.isc(cfg.language), "$(CC) -x c-header $(ALL_CFLAGS)", "$(CXX) -x c++-header $(ALL_CXXFLAGS)")
		_p('\t$(SILENT) %s -o "$@" -MF "$(@:%%.gch=%%.d)" -c "$<"', cmd)
		_p('$(PCH_PLACEHOLDER): $(GCH) | ${OBJDIR}')
		_p('ifeq (posix,$(SHELLTYPE))')
		_p('\t$(SILENT) touch "$@"')
		_p('else')
		_p('\t$(SILENT) echo $null >> "$@"')
		_p('endif')
		_p('else')
		_p('$(OBJECTS): | prebuild')
		_p('endif')
		_p('')
	end
	--]]


	local function getUniqueBasename(cfg, basename)
		cfg._taki.basenameOccurences = cfg._taki.basenameOccurences or {}
		local basenameOccurences = cfg._taki.basenameOccurences
		basenameOccurences[basename] = basenameOccurences[basename] or 0
		local count = basenameOccurences[basename] + 1
		basenameOccurences[basename] = count 
		if count == 1 then
			return basename 
		else
			return basename .. tostring(count - 1)
		end
	end


	local function makeCxxRuleFile(prjLang, cfg, node, filecfg, rule)
		local internalRule = cpp.internalRules[rule.name]
		local toolset = taki.getToolSet(cfg)
		local ts = cpp.toolsets[toolset._taki.basename]
		local categorie = internalRule.categorie
		local extension = ts.extensions[categorie]
		local basename = getUniqueBasename(cfg, node.basename)
		local output = path.join(cfg.objdir, path.replaceextension(basename, extension))
		local buildoutputs = { taki.alias(cfg, output) }

		local pch = cfg._taki.pch
		local dependencies = {}
		if pch.uses then
			dependencies = table.join(dependencies, taki.alias(cfg, pch.output))
		end
		local orderOnlyDependencies = taki.preBuildDependencies(cfg, {})

		local language = internalRule.language
		local flags = '%{ALL_' .. language .. 'FLAGS}'
		local fcfg = fileconfig.getconfig(node, cfg)
		if fcfg then
			local perFileFlags = cpp.perFileFlags(cfg, fcfg)
			if perFileFlags then
				flags = taki.list(perFileFlags)
			end
		end

		local variables = {}
		taki.variable(variables, 'FLAGS', flags)
		if pch.uses then
			taki.variable(variables, 'PCH', pch.useflags)
		end

		local fileRule = {
			node 			= node,
			rule 			= rule,
			name 			= cpp.internalRules[rule.name].name,

			inputs		  	= { node.abspath },
			outputs 		= buildoutputs,
			dependencies	= dependencies,
			orderOnlyDependencies = orderOnlyDependencies,
			variables		= variables,	
			--message  = buildmessage,
			--commands = buildcommands,
			--implicitOutputs = {},
		}

		return fileRule
	end


	local function makeResourceRuleFile(prjLang, cfg, node, filecfg, rule)
		--log:write('ninja_cpp:makeResourceRuleFile -> ' .. node.relpath .. ' ' .. node.basename .. '\n')

		local toolset = taki.getToolSet(cfg)
		local ts = cpp.toolsets[toolset._taki.basename]
		local categorie = cpp.internalRules[rule.name].categorie
		local extension = ts.extensions[categorie]
		local basename = getUniqueBasename(cfg, node.basename)
		local output = path.join(cfg.objdir, path.replaceextension(basename, extension))
		local buildoutputs = { taki.alias(cfg, output) }

		local dependencies = {}
		local orderOnlyDependencies = taki.preBuildDependencies(cfg, {})
				
		local fileRule = {
			node 			= node,
			rule			= rule,
			name 			= cpp.internalRules[rule.name].name,
			
			inputs			= { node.abspath },
			outputs			= buildoutputs,
			dependencies	= dependencies,
			orderOnlyDependencies = orderOnlyDependencies,
		}

		return fileRule
	end


	function cpp.makeRuleFile(prjLang, cfg, node, filecfg, rule)
		--log:write('cpp.makeRuleFile -> ' .. node.relpath .. '\n')

		if cpp.internalRules[rule.name] then
			if rule.name == 'special_rule_cxx' then
				return makeCxxRuleFile(prjLang, cfg, node, filecfg, rule)				
			elseif rule.name == 'special_rule_cc' then
				return makeCxxRuleFile(prjLang, cfg, node, filecfg, rule)				
			elseif rule.name == 'special_rule_resource' then
				return makeResourceRuleFile(prjLang, cfg, node, filecfg, rule)				
			else 
				return nil
			end
		else
			return taki.makeNormalRuleFile(prjLang, cfg, node, filecfg, rule)
		end
	end

