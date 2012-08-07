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
		def buildDo
			if(targets.size != 1 || (!targets[0].is_a?(MakeRb::FileRes)))
				throw "Invalid target specification"
			end
			sources.each { |s|
				if (!s.is_a?(MakeRb::FileRes))
					throw "Invalid source specification"
				end
			}
			
			cxx = sources.inject(false) { |o,s| o || s.is_a?(CxxFile) }
			
			[if cxx then "g++" else "gcc" end, "-fPIC", "-c", "-o", targets[0].filename] + sources.map{|s| s.filename }
		end
	end
	class Linker < MakeRbBinary::Linker
		def buildDo
			if(targets.size != 1 || (!targets[0].is_a?(MakeRbBinary::LinkedFile)))
				throw "Invalid target specification"
			end
			sources.each { |s|
				if (!s.is_a?(MakeRb::FileRes))
					throw "Invalid source specification"
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
