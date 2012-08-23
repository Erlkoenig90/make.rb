#!/usr/bin/env ruby

module MakeRbBinary
	class AsmFile < MakeRb::FileRes
	end
	class ObjFile < MakeRb::FileRes
		include MakeRb::Generated;
		def ObjFile.auto(src)
			ObjFile.new(src.buildMgr, src.filename.sub_ext(".o"))
		end
	end
	class LinkedFile < MakeRb::FileRes
		include MakeRb::Generated;
	end
	class DynLibrary < LinkedFile
	end
	class StaticLibrary < LinkedFile
	end
	class Executable < LinkedFile
	end
	class Linker < MakeRb::Builder
	end
	class LinkerScript < MakeRb::FileRes
	end
end
