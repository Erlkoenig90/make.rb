#!/usr/bin/env ruby

module MakeRbBinary
	class ObjFile < MakeRb::FileRes
		include MakeRb::Generated;
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
end
