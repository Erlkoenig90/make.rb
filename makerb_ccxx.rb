#!/usr/bin/env ruby

module MakeRbCCxx
	class CFile < MakeRb::FileRes
	end
	class CxxFile < MakeRb::FileRes
	end
	class CObjFile < MakeRbBinary::ObjFile
		def CObjFile.auto(src)
			CObjFile.new(src.filename.sub_ext(".o"))
		end
	end
	class CxxObjFile < MakeRbBinary::ObjFile
		def CxxObjFile.auto(src)
			CxxObjFile.new(src.filename.sub_ext(".o"))
		end
	end
	
	class Compiler < MakeRb::Builder
	end
	class GCC < Compiler
		attr_reader :platform, :buildMgr, :flags
		def buildDo
			if(targets.size != 1 || (!targets[0].is_a?(MakeRb::FileRes)))
				raise "Invalid target specification"
			end
			sources.each { |s|
				if (!s.is_a?(MakeRb::FileRes))
					raise "Invalid source specification"
				end
			}
			
			cxx = sources.inject(false) { |o,s| o || s.is_a?(CxxFile) }
			tool = if(cxx) then "g++" else "gcc" end
			p_flags = if(cxx) then platform.settings.cxx[self.class].flags else platform.settings.cc[self.class].flags end
			b_flags = if(cxx) then buildMgr.settings.cxx[self.class].flags else buildMgr.settings.cc[self.class].flags end
			
			[platform.cl_prefix[self.class] + tool, "-c", "-o", targets[0].filename.to_s] + sources.map{|s| s.filename.to_s } + flags.get + p_flags.get + b_flags.get
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
			
			if (targets[0].is_a?(MakeRbBinary::StaticLibrary))
				["ar", "rcs", targets[0].filename.to_s] + sources.map{|s| s.filename.to_s }
			else
				cxx = sources.inject(false) { |o,s| o || s.is_a?(CxxObjFile) }
			
				tool = if cxx then "g++" else "gcc" end
				
				p_flags = platform.settings.ld[self.class].flags
				b_flags = buildMgr.settings.ld[self.class].flags

				[platform.cl_prefix[self.class] + tool] + if (targets[0].is_a?(MakeRbBinary::DynLibrary))
					["-shared"]
				else
					[]
				end + ["-o", targets[0].filename.to_s] + sources.map{|s| s.filename.to_s } + flags.get + p_flags.get + b_flags.get
			end
		end
	end
	
	def MakeRbCCxx.compilers
		@compilers ||= {"gcc" => ["GNU Compiler Collection", GCC, GCCLinker], "cl" => ["Microsoft C/C++ Compiler", nil, nil]}
	end
end
