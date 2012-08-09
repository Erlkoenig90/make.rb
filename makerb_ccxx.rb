#!/usr/bin/env ruby

module MakeRbCCxx
	class CFile < MakeRb::FileRes
	end
	class CxxFile < MakeRb::FileRes
	end
	class CObjFile < MakeRbBinary::ObjFile
	end
	class CxxObjFile < MakeRbBinary::ObjFile
	end
	
	class Compiler < MakeRb::Builder
	end
	class GCC < Compiler
		attr_reader :flags
		def initialize(flags, *x)
			super(*x)
			@flags = flags
		end
		def buildDo(mgr)
			if(targets.size != 1 || (!targets[0].is_a?(MakeRb::FileRes)))
				raise "Invalid target specification"
			end
			sources.each { |s|
				if (!s.is_a?(MakeRb::FileRes))
					raise "Invalid source specification"
				end
			}
			
			cxx = sources.inject(false) { |o,s| o || s.is_a?(CxxFile) }
			tool = if(cxx) then "g++" else "gcc"
			p_flags = if(cxx) then mgr.platform.cxx_flags else mgr.platform.cc_flags end
			
			[mgr.platform.cl_prefix + tool, "-c", "-o", targets[0].filename] + sources.map{|s| s.filename } + flags + p_flags
		end
	end
	class Linker < MakeRbBinary::Linker
		def buildDo(mgr)
			if(targets.size != 1 || (!targets[0].is_a?(MakeRbBinary::LinkedFile)))
				raise "Invalid target specification"
			end
			sources.each { |s|
				if (!s.is_a?(MakeRb::FileRes))
					raise "Invalid source specification"
				end
			}
			
			if (targets[0].is_a?(MakeRbBinary::StaticLibrary))
				cmd = ["ar", "rcs", targets[0].filename]
			else
				cxx = sources.inject(false) { |o,s| o || s.is_a?(CxxObjFile) }
			
				cmd = [if cxx then "g++" else "gcc" end]
			
				if (targets[0].is_a?(MakeRbBinary::DynLibrary))
					cmd = cmd + ["-shared"]
				end
				cmd = cmd + ["-o", targets[0].filename, "-fPIC"]
			end
			cmd + sources.map{|s| s.filename }
		end
	end
end
