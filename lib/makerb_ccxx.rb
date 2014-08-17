#!/usr/bin/env ruby

require 'makerb_settings'

module MakeRbCCxx
	# A C source file
	class CFile < MakeRb::FileRes
		def srcSpecialisations
			MakeRb::SettingsKey[:language => MakeRbLang::C]
		end
	end
	# A C++ source file
	class CxxFile < MakeRb::FileRes
		def srcSpecialisations
			MakeRb::SettingsKey[:language => MakeRbLang::Cxx]
		end
	end
	# A C++11 source file
	class Cxx11File < CxxFile
		def srcSpecialisations
			MakeRb::SettingsKey[:language => MakeRbLang::Cxx11]
		end
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
	
	# File containing hexadecimal (intel hex) representation of a program image
	class HexFile < MakeRb::FileRes
    include MakeRb::Generated;
  end
  # Flat binary program image
  class BinFile < MakeRb::FileRes
    include MakeRb::Generated;
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
		def aTarget
			@aTarget ||= targets.find { |t| t.is_a?(MakeRbBinary::AsmListingFile) }
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
				(MakeRb::SettingsKey[:builder => self, :toolchain => MakeRbCCxx.tc_gcc] + sumSpecialisations))
			prefix = (s[:clPrefix]) || ("")
			cpp = (s[:cppDefines] || {}).map{|n,v| "-D#{n}=#{v}"}
			
			
			[prefix + tool, "-c"] +
				sources.select{ |s| !s.is_a?(MakeRb::ImplicitSrc) }.map{|s| s.buildMgr.effective(s.filename).to_s } +
					GCC.getFlags(s, @buildMgr) + cpp
		end
		def GCC.getFlags(s,mgr = nil)
			flags = s[:clFlags] || []
			includes = (s[:includeDirs] || []).map{|inc| "-I" + (if(mgr == nil) then inc else mgr.effective(inc) end).to_s }
			
			flags + includes
		end
		def buildDo(ms)
			targets.each { |t| t.makePath }
			ms.runcmd(baseCmd + ["-o", oTarget.buildMgr.effective(oTarget.filename).to_s] +
				if(aTarget == nil) then [] else ["-Wa,-aln=" + aTarget.buildMgr.effective(aTarget.filename).to_s] end)
		end
	end
	class GCCDepGen < GCC
		include DepGen
		attr_reader :ofile
		def initialize(*x, ofile)
			@ofile = ofile
			super(*x)
		end
		def buildDo(ms)
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
		def buildDo(ms)
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
				
					
				startup = []
				isrVector = []
				ldScript = sources.find { |s| s.is_a?(MakeRbBinary::LinkerScript) }
				ldScript = if(ldScript != nil)
					ldScript.buildMgr.effective(ldScript.filename)
				else
					c = s[:startupCode]
					startup = if(c == nil)
						[]
					elsif(cxx)
						["-x","c",c.to_s]
					else
						[c.to_s]
					end
					c = s[:isrVector]
					isrVector = if(c == nil)
						[]
					elsif(cxx)
						["-x","c",c.to_s]
					else
						[c.to_s]
					end
					s[:linkerScript]
				end
				ldScript = if(ldScript == nil) then [] else ["-T", ldScript.to_s] end
				
				if(s[:circularLookup])
					before = ["-Wl,--start-group"]
					after = ["-Wl,--end-group"]
				else
					before = []
					after = []
				end
				
				ms.runcmd([prefix + tool] + if (targets[0].is_a?(MakeRbBinary::DynLibrary))
					["-shared"]
				else
					[]
				end + ["-o", targets[0].buildMgr.effective(targets[0].filename).to_s] + before +
						sources.select{ |s| !s.is_a?(MakeRb::ImplicitSrc) && !s.is_a?(MakeRbBinary::LinkerScript) }.map{|s| s.buildMgr.effective(s.filename).to_s } +
						startup + isrVector + ldScript + after + GCCLinker.getFlags(s,@buildMgr))
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
	# "objdump" disassembler
	class GCCDisasm < MakeRbBinary::Disassembler
		def buildDo(ms)
			s = buildMgr.settings.getSettings(
				MakeRb::SettingsKey[:builder => self, :toolchain => MakeRbCCxx.tc_gcc] + sumSpecialisations)
			prefix = s[:clPrefix] || ""
		  
			ms.runcmd([prefix + "objdump", "-d", "-t", "-C"] + sources.map { |src| src.effective.to_s },  targets.find { |t| t.is_a?(FileRes) }.effective.to_s)
		end
	end
	
	# The binutils objcopy program for converting object file formats
	class Objcopy < MakeRb::Builder
    def buildDo(ms)
      s = buildMgr.settings.getSettings(sumSpecialisations)
      prefix = s[:clPrefix] || ""
      ms.runcmd([prefix + "objcopy", "-O", targets[0].is_a?(HexFile) ? "ihex" : "binary", sources[0].effective.to_s, targets[0].effective.to_s])
    end
  end

	
	# Represents a toolchain - i.e. compiler, assembler, linker
	class ClToolchain
		attr_reader :compiler, :desc, :assembler, :linker, :depgen, :name, :disassembler
		def initialize(n, d, cl, as, ld, dg, da)
			@name = n
			@desc = d
			@compiler = cl
			@assembler = as
			@linker = ld
			@depgen = dg
			@disassembler = da
		end
		def to_s
			@name
		end
		def inspect
			"MakeRbCCxx.toolchains[" + name.inspect + "]"
		end
	end
	# The GCC toolchain
	# @return [ClToolchain]
	def MakeRbCCxx.tc_gcc
		@@tc_gcc ||= ClToolchain.new("gcc", "GNU Compiler Collection", GCC, GCC, GCCLinker, GCCDepGen, GCCDisasm)
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
		def to_s
			"C"
		end
		def inspect
			"MakeRbLang.C"
		end
	end
	# C++
	module Cxx
		def Cxx.parentSettings
			C
		end
		def to_s
			"C++"
		end
		def inspect
			"MakeRbLang.Cxx"
		end
	end
	# C++11
	module Cxx11
		def Cxx11.parentSettings
			Cxx
		end
		def to_s
			"C++11"
		end
		def inspect
			"MakeRbLang.Cxx11"
		end
	end
	module Ruby
		def to_s
			"ruby"
		end
		def inspect
			"MakeRbLang.Ruby"
		end
	end
	# Assembler
	module Asm
		def to_s
			"asm"
		end
		def inspect
			"MakeRbLang.Asm"
		end
	end
	# Various language-specific settings
	def MakeRbLang.settings
		@@langSettings ||= MakeRb::SettingsMatrix[
			{:toolchain => MakeRbCCxx.tc_gcc, :language => C, :debug => true} => {:clFlags => ["-g"], :ldFlags => ["-g"]},
			{:toolchain => MakeRbCCxx.tc_gcc, :language => C, :removeUnusedFunctions => true} => {:clFlags => ["-ffunction-sections", "-fdata-sections"], :ldFlags => ["-Wl,--gc-sections"]},
			{:toolchain => MakeRbCCxx.tc_gcc, :language => Cxx, :exceptions => false} => {:clFlags => ["-fno-exceptions"]},
			{:toolchain => MakeRbCCxx.tc_gcc, :language => Cxx, :rtti => false} => {:clFlags => ["-fno-rtti"]},
			{:toolchain => MakeRbCCxx.tc_gcc, :language => Cxx11} => {:clFlags => ["-std=c++11"]},
			{:toolchain => MakeRbCCxx.tc_gcc, :resourceClass => MakeRbCCxx::CFile} => { :fileExt => ".c" }, 
			{:toolchain => MakeRbCCxx.tc_gcc, :resourceClass => MakeRbCCxx::CxxFile} => { :fileExt => ".cc" }, 
			{:toolchain => MakeRbCCxx.tc_gcc, :resourceClass => MakeRbBinary::AsmFile} => { :fileExt => ".S" }, 
			{:toolchain => MakeRbCCxx.tc_gcc, :resourceClass => MakeRbBinary::AsmListingFile} => { :fileExt => ".S" }, 
			{:toolchain => MakeRbCCxx.tc_gcc, :resourceClass => MakeRbBinary::ObjFile} => { :fileExt => ".o" },
			{:toolchain => MakeRbCCxx.tc_gcc, :resourceClass => MakeRbBinary::LinkerScript} => { :fileExt => ".ld" },
		]
	end
end
