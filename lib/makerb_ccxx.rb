#!/usr/bin/env ruby

module MakeRbCCxx
	class CFile < MakeRb::FileRes
	end
	class CxxFile < MakeRb::FileRes
	end
	class CObjFile < MakeRbBinary::ObjFile
		def CObjFile.auto(src)
			CObjFile.new(src.buildMgr, src.filename.sub_ext(".o"))
		end
	end
	class CxxObjFile < MakeRbBinary::ObjFile
		def CxxObjFile.auto(src)
			CxxObjFile.new(src.buildMgr, src.filename.sub_ext(".o"))
		end
	end
	class Header < MakeRb::FileRes
		include MakeRb::ImplicitSrc
	end
	class Compiler < MakeRb::Builder
	end
	module DepGen
	end
	class GCC < Compiler
		def oTarget
			@oTarget ||= targets.find { |t| t.is_a?(MakeRbBinary::ObjFile) }
		end
		def depTarget
			@depTarget ||= targets.find { |t| t.is_a?(MakeRb::DepMakeFile) }
		end
		
		def baseCmd
			sources.each { |s|
				if (!s.is_a?(MakeRb::FileRes))
					raise "Invalid source specification"
				end
			}
			
			cxx = sources.inject(false) { |o,s| o || s.is_a?(CxxFile) }
			tool = if(cxx) then "g++" else "gcc" end
			lang = if(cxx) then MakeRbLang::Cxx else MakeRbLang::C end
			
			s = buildMgr.settings.getSettings(
				(MakeRb::SettingsKey[:language => lang, :builder => self, :toolchain => MakeRbCCxx.tc_gcc] + specialisations))
			flags = s[:clFlags] || []
			prefix = (s[:clPrefix]) || ("")
			includes = (s[:includeDirs] || []).map{|inc| "-I" + buildMgr.effective(inc).to_s }
			
			[prefix + tool, "-c"] +
				sources.select{ |s| !s.is_a?(MakeRb::ImplicitSrc) }.map{|s| s.buildMgr.effective(s.filename).to_s } +
					flags + includes
		end
		def buildDo
			targets.each { |t| t.makePath }
			baseCmd + ["-o", oTarget.buildMgr.effective(oTarget.filename).to_s]
		end
	end
	class GCCDepGen < GCC
		include DepGen
		attr_reader :ofile
		def initialize(*x, ofile)
			@ofile = ofile
			super(*x)
		end
		def buildDo
			if(depTarget == nil)
				raise "No .dep target specified"
			end
			targets.each { |t| t.makePath }
			baseCmd + if depTarget == nil then [] else
				["-M", "-MT", ofile.filename.to_s, "-MF", depTarget.filename.to_s]
			end
		end
	end
	class GCCLinker < MakeRbBinary::Linker
		def buildDo
			if(targets.size != 1 || (!targets[0].is_a?(MakeRbBinary::LinkedFile)))
				raise "Invalid target specification"
			end
			sources.each { |s|
				if (!s.is_a?(MakeRb::FileRes))
					raise "Invalid source specification"
				end
			}
			
			targets[0].makePath
			if (targets[0].is_a?(MakeRbBinary::StaticLibrary))
				["ar", "rcs", targets[0].filename.to_s] + sources.map{|s| s.filename.to_s }
			else
				cxx = sources.inject(false) { |o,s| o || s.is_a?(CxxObjFile) }
			
				tool = if cxx then "g++" else "gcc" end
				
				lang = if(cxx) then MakeRbLang::Cxx else MakeRbLang::C end
				
				s = buildMgr.settings.getSettings(
					MakeRb::SettingsKey[:language => lang, :builder => self, :toolchain => MakeRbCCxx.tc_gcc] + specialisations)
				
						
				
				flags = (s[:ldFlags] || []) + (s[:libraryFiles] || []).map { |f| @buildMgr.effective(f).to_s }
				prefix = s[:clPrefix] || ""
				
				ldScript = sources.find { |s| s.is_a?(MakeRbBinary::LinkerScript) }
				ldScript = if(ldScript == nil) then [] else ["-T", ldScript.buildMgr.effective(ldScript.filename).to_s] end
				
				[prefix + tool] + if (targets[0].is_a?(MakeRbBinary::DynLibrary))
					["-shared"]
				else
					[]
				end + ["-o", targets[0].buildMgr.effective(targets[0].filename).to_s] +
					sources.select{ |s| !s.is_a?(MakeRb::ImplicitSrc) && !s.is_a?(MakeRbBinary::LinkerScript) }.map{|s| s.buildMgr.effective(s.filename).to_s } +
						ldScript + flags
			end
		end
	end
	class ClToolchain
		attr_reader :compiler, :assembler, :linker, :depgen, :name
		def initialize(n, cl, as, ld, dg)
			@name = n
			@compiler = cl
			@assembler = as
			@linker = ld
			@depgen = dg
		end
	end
	def MakeRbCCxx.tc_gcc
		@@tc_gcc ||= ClToolchain.new("GNU Compiler Collection", GCC, GCC, GCCLinker, GCCDepGen)
	end
	def MakeRbCCxx.toolchains
		@compilers ||= {"gcc" => MakeRbCCxx.tc_gcc}
#						"cl" => ClToolchain.new("Microsoft C/C++ Compiler", nil, nil, nil)}
	end
	def MakeRbCCxx.autoProgram(mgr, exeName, sourceNames, options)
		autoGeneric(mgr, exeName, MakeRbBinary::Executable, sourceNames, options)
	end
	def MakeRbCCxx.autoDynLib(mgr, exeName, sourceNames, options)
		autoGeneric(mgr, exeName, MakeRbBinary::DynLibrary, sourceNames, options)
	end
	def MakeRbCCxx.autoStaticLib(mgr, exeName, sourceNames, options)
		autoGeneric(mgr, exeName, MakeRbBinary::StaticLibrary, sourceNames, options)
	end
	def MakeRbCCxx.autoGeneric(mgr, exeName, exeClass, sourceNames, options)
		cFiles = []
		cxxFiles = []
		asmFiles = []
		sourceNames.each { |fn|
			ext = File.extname(fn).downcase
			if(ext == ".cpp" || ext == ".cxx" || ext == ".cc")
				cxxFiles << fn
			elsif(ext == ".s" || ext == ".asm")
				asmFiles << fn
			else
				cFiles << fn
			end
		}
		
#		mgr.join(mgr.pf_host, mgr.pf_host.settings.def_toolchain.linker, MakeRbBinary::Executable, (
#			mgr.newchain(mgr.pf_host, [CxxFile, mgr.pf_host.settings.def_toolchain.compiler, CxxObjFile], cxxFiles) +
#			mgr.newchain(mgr.pf_host, [CFile, mgr.pf_host.settings.def_toolchain.compiler, CObjFile], cFiles)),
#			exeName)
		
		ofiles = cFiles.map { |f|
			s = CFile.new(mgr, f)
			o = CObjFile.auto(s)
			d = MakeRb::DepMakeFile.auto(s)
			g = mgr.pf_host.settings.def_toolchain.depgen.new(mgr.pf_host, mgr, s, d, nil, o)
			b = mgr.pf_host.settings.def_toolchain.compiler.new(mgr.pf_host, mgr, [s, d], o, nil)
			o
		} + cxxFiles.map { |f|
			s = CxxFile.new(mgr, f)
			o = CxxObjFile.auto(s)
			d = MakeRb::DepMakeFile.auto(s)
			g = mgr.pf_host.settings.def_toolchain.depgen.new(mgr.pf_host, mgr, s, d, nil, o)
			b = mgr.pf_host.settings.def_toolchain.compiler.new(mgr.pf_host, mgr, [s, d], o, nil)
			o
		} + asmFiles.map { |f|
			s = MakeRbBinary::AsmFile.new(mgr, f)
			o = MakeRbBinary::ObjFile.auto(s)
			b = mgr.pf_host.settings.def_toolchain.assembler.new(mgr.pf_host, mgr, s, o, nil)
			o
		}
		
		exe = exeClass.new(mgr, exeName)
		ld = mgr.pf_host.settings.def_toolchain.linker.new(mgr.pf_host, mgr, ofiles, exe, nil)
		
		if(options.include?(:pkgconfig))
#			mgr.settings.cc.includes <<  
			mgr.settings.cxx.specific[mgr.pf_host.settings.def_toolchain].flags << MakeRb::PkgConfigCflags.new(options[:pkgconfig])
			mgr.settings.ld.specific[mgr.pf_host.settings.def_toolchain].flags << MakeRb::PkgConfigLDflags.new(options[:pkgconfig])
		end
		if(options.include?(:ccflags))
			mgr.settings.cc.specific[mgr.pf_host.settings.def_toolchain].flags.concat(
				options[:ccflags].map { |str| MakeRb::StaticFlag.new(str) })
		end
		if(options.include?(:cxxflags))
			mgr.settings.cxx.specific[mgr.pf_host.settings.def_toolchain].flags.concat(
				options[:cxxflags].map { |str| MakeRb::StaticFlag.new(str) })
		end
		if(options.include?(:ldflags))
			mgr.settings.ld.specific[mgr.pf_host.settings.def_toolchain].flags.concat(
				options[:ldflags].map { |str| MakeRb::StaticFlag.new(str) })
		end
		if(options.include?(:c_includes))
			mgr.settings.cc.includes.concat(options[:c_includes].map { |i| MakeRb::IncludeDir.new(i) })
		end
		if(options.include?(:cxx_includes))
			mgr.settings.cxx.includes.concat(options[:cxx_includes].map { |i| MakeRb::IncludeDir.new(i) })
		end
		if(options.include?(:ownheaders))
			mgr.resources.concat(options[:ownheaders].map{|f| Header.new(mgr, f) })
		end
		if(options.include?(:ldscript))
			ld.sources << MakeRbBinary::LinkerScript.new(mgr, options[:ldscript])
		end
		if(options.include?(:mlc_libs))
			ld.settings.libraries.concat(options[:mlc_libs].map { |l| mgr.mlc[l] })
		end
		if(options.include?(:sys_libs))
			ld.settings.libraries.concat(options[:sys_libs].map { |l| MakeRb::SystemLibrary.new(l) })
		end
		exe
	end
end

module MakeRbLang
	module C
	end
	module Cxx
		def Cxx.parentSettings
			C
		end
	end
	module Ruby
	end
	module Asm
	end
	def MakeRbLang.settings
		MakeRb::SettingsMatrix.new(
			{:toolchain => MakeRbCCxx.tc_gcc, :debug => true, :language => C} => { :clFlags => ["-g"] },
		)
	end
end
