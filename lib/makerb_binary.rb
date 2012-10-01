#!/usr/bin/env ruby

# Contains classes for dealing with compiled/binary files, e.g. C programs, and C object files.
module MakeRbBinary
	# An Assembler source
	class AsmFile < MakeRb::FileRes
	end
	# An object file, i.e. the result of compiling (but not linking) a C source.
	class ObjFile < MakeRb::FileRes
		include MakeRb::Generated;
		def ObjFile.auto(src)
			ObjFile.new(src.buildMgr, src.filename.sub_ext(".o"))
		end
	end
	# The product of linking, i.e. an executable binary or a library.
	class LinkedFile < MakeRb::FileRes
		include MakeRb::Generated;
	end
	# A dynamic library (e.g. a .so on linux systems, a .dll on windows systems)
	class DynLibrary < LinkedFile
		# See {MakeRb::Resource#destSpecialisations}
		def destSpecialisations
			MakeRb::SettingsKey[:staticLinking => false] + super
		end
	end
	# A static library - this deriving from {LinkedFile} is not strictly correct, because e.g. on Linux these
	# are just archives of object files. 
	class StaticLibrary < LinkedFile
		# See {MakeRb::Resource#destSpecialisations}
		def destSpecialisations
			MakeRb::SettingsKey[:staticLinking => true] + super
		end
	end
	# An executable binary, e.g. an .exe on Windows.
	class Executable < LinkedFile
	end
	# A builder that links object files and libraries into new libraries or executables.
	class Linker < MakeRb::Builder
	end
	# A file to configure a linker's behaviour (e.g. .ld files when using GCC)
	class LinkerScript < MakeRb::FileRes
	end
end
