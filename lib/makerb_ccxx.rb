#!/usr/bin/env ruby

module MakeRbCCxx
	# A C source file
	class CFile < MakeRb::FileRes
	end
	# A C++ source file
	class CxxFile < MakeRb::FileRes
	end
	# An object file, result of compiling a C file
	class CObjFile < MakeRbBinary::ObjFile
	end
	# An object file, result of compiling a C++ file. Use this to indicate that C++ options should be used for linking.
	class CxxObjFile < MakeRbBinary::ObjFile
	end
	# A header file - used for dependency tracking
	class Header < MakeRb::FileRes
		include MakeRb::ImplicitSrc
	end
	# A generic C/C++ compiler. Derived classes should implement concrete compilers
	class Compiler < MakeRb::Builder
	end
	module DepGen
	end
	# The C/C++ Compiler from the GNU Compiler Collection
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
				(MakeRb::SettingsKey[:language => lang, :builder => self, :toolchain => MakeRbCCxx.tc_gcc] + sumSpecialisations))
			prefix = (s[:clPrefix]) || ("")
			
			[prefix + tool, "-c"] +
				sources.select{ |s| !s.is_a?(MakeRb::ImplicitSrc) }.map{|s| s.buildMgr.effective(s.filename).to_s } +
					GCC.getFlags(s, @buildMgr)
		end
		def GCC.getFlags(s,mgr = nil)
			flags = s[:clFlags] || []
			includes = (s[:includeDirs] || []).map{|inc| "-I" + (if(mgr == nil) then inc else mgr.effective(inc) end).to_s }
			
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
	# Uses the GCC frontend for linking
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
					MakeRb::SettingsKey[:language => lang, :builder => self, :toolchain => MakeRbCCxx.tc_gcc] + sumSpecialisations)
				
				prefix = s[:clPrefix] || ""
				
				ldScript = sources.find { |s| s.is_a?(MakeRbBinary::LinkerScript) }
				ldScript = if(ldScript == nil) then [] else ["-T", ldScript.buildMgr.effective(ldScript.filename).to_s] end
				
				if(s[:circularLookup])
					before = ["-Wl,--start-group"]
					after = ["-Wl,--end-group"]
				else
					before = []
					after = []
				end
				
				[prefix + tool] + if (targets[0].is_a?(MakeRbBinary::DynLibrary))
					["-shared"]
				else
					[]
				end + ["-o", targets[0].buildMgr.effective(targets[0].filename).to_s] +
					before + sources.select{ |s| !s.is_a?(MakeRb::ImplicitSrc) && !s.is_a?(MakeRbBinary::LinkerScript) }.map{|s| s.buildMgr.effective(s.filename).to_s } + after +
						ldScript + GCCLinker.getFlags(s,@buildMgr)
			end
		end
		def GCCLinker.getFlags(s,mgr=nil)
			(s[:ldFlags] || []) + ((s[:libraryFiles] || []).map { |lib|
				if(lib.is_a?(MakeRbExt::ShippedLibRef))
					(if(mgr == nil) then lib.name else mgr.effective(lib.name) end).to_s
				else
					MakeRb.findFile(lib.name, s[:SysLibPaths] || [], s[:libRefNaming] || []).to_s
				end
			})
		end
	end
	# Represents a toolchain - i.e. compiler, assembler, linker
	class ClToolchain
		attr_reader :compiler, :desc, :assembler, :linker, :depgen, :name
		def initialize(n, d, cl, as, ld, dg)
			@name = n
			@desc = d
			@compiler = cl
			@assembler = as
			@linker = ld
			@depgen = dg
		end
	end
	# The GCC toolchain
	# @return [ClToolchain]
	def MakeRbCCxx.tc_gcc
		@@tc_gcc ||= ClToolchain.new("gcc", "GNU Compiler Collection", GCC, GCC, GCCLinker, GCCDepGen)
	end
	# Hash of toolchains
	# @return [Hash]
	def MakeRbCCxx.toolchains
		@compilers ||= {"gcc" => MakeRbCCxx.tc_gcc}
#						"cl" => ClToolchain.new("Microsoft C/C++ Compiler", nil, nil, nil)}
	end
end

# Provides identifiers for programming languages
module MakeRbLang
	module C
	end
	# C++
	module Cxx
		def Cxx.parentSettings
			C
		end
	end
	module Ruby
	end
	# Assembler
	module Asm
	end
	# Various language-specific settings
	def MakeRbLang.settings
		MakeRb::SettingsMatrix.new(
			{{:toolchain => MakeRbCCxx.tc_gcc, :debug => true, :language => C} => MakeRb::Settings[:clFlags => ["-g"]],
				{:toolchain => MakeRbCCxx.tc_gcc, :resourceClass => MakeRbCCxx::CFile} => MakeRb::Settings[ :fileExt => ".c" ], 
				{:toolchain => MakeRbCCxx.tc_gcc, :resourceClass => MakeRbCCxx::CxxFile} => MakeRb::Settings[ :fileExt => ".cc" ], 
				{:toolchain => MakeRbCCxx.tc_gcc, :resourceClass => MakeRbBinary::AsmFile} => MakeRb::Settings[ :fileExt => ".s" ], 
				{:toolchain => MakeRbCCxx.tc_gcc, :resourceClass => MakeRbBinary::ObjFile} => MakeRb::Settings[ :fileExt => ".o" ],
				{:toolchain => MakeRbCCxx.tc_gcc, :resourceClass => MakeRbBinary::LinkerScript} => MakeRb::Settings[ :fileExt => ".ld" ]},
		)
	end
end
