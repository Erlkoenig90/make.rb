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
		attr_reader :platform, :buildMgr, :flags
		def oTarget
			@oTarget ||= MakeRb.findWhere(targets) { |t| t.is_a?(MakeRbBinary::ObjFile) }
		end
		def depTarget
			@depTarget ||= MakeRb.findWhere(targets) { |t| t.is_a?(MakeRb::DepMakeFile) }
		end
		
		def baseCmd
			sources.each { |s|
				if (!s.is_a?(MakeRb::FileRes))
					raise "Invalid source specification"
				end
			}
			
			cxx = sources.inject(false) { |o,s| o || s.is_a?(CxxFile) }
			tool = if(cxx) then "g++" else "gcc" end
			p_flags = if(cxx) then platform.settings.cxx.specific[MakeRbCCxx.tc_gcc].flags else platform.settings.cc.specific[MakeRbCCxx.tc_gcc].flags end
			b_flags = if(cxx) then buildMgr.settings.cxx.specific[MakeRbCCxx.tc_gcc].flags else buildMgr.settings.cc.specific[MakeRbCCxx.tc_gcc].flags end
			d_flag = if(platform.settings.debug || buildMgr.settings.debug) then ["-g"] else [] end
			
			i_flags = (buildMgr.settings.cc.includes + (if(cxx) then buildMgr.settings.cxx.includes else [] end)).map { |i| "-I" + i.to_s }.uniq
			
			[platform.cl_prefix[self.class] + tool, "-c"] +
				sources.select{ |s| !s.is_a?(MakeRb::ImplicitSrc) }.map{|s| s.filename.to_s } +
					flags.get + p_flags.get + b_flags.get + d_flag + i_flags
		end
		def buildDo
			targets.each { |t| t.makePath }
			baseCmd + ["-o", oTarget.filename.to_s]
		end
	end
	class GCCDepGen < GCC
		include DepGen
		attr_reader :ofile
		def initialize(ofile, *x)
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
				
				p_flags = platform.settings.ld.specific[MakeRbCCxx.tc_gcc].flags
				b_flags = buildMgr.settings.ld.specific[MakeRbCCxx.tc_gcc].flags
				d_flag = if(platform.settings.debug || buildMgr.settings.debug) then ["-g"] else [] end
				
				ldScript = MakeRb.findWhere(sources) { |s| s.is_a?(MakeRbBinary::LinkerScript) }
				ldScript = if(ldScript == nil) then [] else ["-T", ldScript.filename.to_s] end
				
				# TODO Library flags

				[platform.cl_prefix[MakeRbCCxx.tc_gcc] + tool] + if (targets[0].is_a?(MakeRbBinary::DynLibrary))
					["-shared"]
				else
					[]
				end + ["-o", targets[0].filename.to_s] +
					sources.select{ |s| !s.is_a?(MakeRb::ImplicitSrc) && !s.is_a?(MakeRbBinary::LinkerScript) }.map{|s| s.filename.to_s } +
						ldScript + flags.get + p_flags.get + b_flags.get + d_flag
			end
		end
	end
	class ClToolchain
		attr_reader :compiler, :linker, :depgen, :name
		def initialize(n, cl, ld, dg)
			@name = n
			@compiler = cl
			@linker = ld
			@depgen = dg
		end
	end
	def MakeRbCCxx.tc_gcc
		@@tc_gcc ||= ClToolchain.new("GNU Compiler Collection", GCC, GCCLinker, GCCDepGen)
	end
	def MakeRbCCxx.toolchains
		@compilers ||= {"gcc" => MakeRbCCxx.tc_gcc}
#						"cl" => ClToolchain.new("Microsoft C/C++ Compiler", nil, nil, nil)}
	end
	def MakeRbCCxx.autoProgram(mgr, exeName, sourceNames, options)
		cFiles = []
		cxxFiles = []
		sourceNames.each { |fn|
			ext = File.extname(fn).downcase
			if(ext == ".cpp" || ext == ".cxx" || ext == ".cc")
				cxxFiles << fn
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
			g = mgr.pf_host.settings.def_toolchain.depgen.new(o, mgr.pf_host, mgr, nil, s, d)
			b = mgr.pf_host.settings.def_toolchain.compiler.new(mgr.pf_host, mgr, nil, [s, d], o)
			o
		} + cxxFiles.map { |f|
			s = CxxFile.new(mgr, f)
			o = CxxObjFile.auto(s)
			d = MakeRb::DepMakeFile.auto(s)
			g = mgr.pf_host.settings.def_toolchain.depgen.new(o, mgr.pf_host, mgr, nil, s, d)
			b = mgr.pf_host.settings.def_toolchain.compiler.new(mgr.pf_host, mgr, nil, [s, d], o)
			o
		}
		
		exe = MakeRbBinary::Executable.new(mgr, exeName)
		ld = mgr.pf_host.settings.def_toolchain.linker.new(mgr.pf_host, mgr, nil, ofiles, exe)
		
		if(options.include?(:pkgconfig))
			mgr.settings.cc.specific[mgr.pf_host.settings.def_toolchain].flags << MakeRb::PkgConfigCflags.new(options[:pkgconfig])
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
			mgr.settings.cc.includes.concat(options[:c_includes])
		end
		if(options.include?(:cxx_includes))
			mgr.settings.cxx.includes.concat(options[:cxx_includes])
		end
		if(options.include?(:ownheaders))
			mgr.resources.concat(options[:ownheaders].map{|f| Header.new(mgr, f) })
		end
		if(options.include?(:ldscript))
			ld.sources << MakeRbBinary::LinkerScript.new(mgr, options[:ldscript])
		end
	end
end
