#!/usr/bin/env ruby

module MakeRb
	class Flag
	end
	class StaticFlag < Flag
		def initialize(str)
			@str = str
		end
		def get
			[@str]
		end
	end
	class PkgConfigCflags < Flag
		def initialize(pkgnames)
			@pkgnames = if pkgnames.is_a? Array
				pkgnames
			else
				[pkgnames]
			end
		end
		def get
			cmd = "pkg-config --cflags " + @pkgnames.join(" ")
			# TODO - do better parsing here
			@res ||= `#{cmd}`.split(" ")
		end
	end
	class PkgConfigLDflags < Flag
		def initialize(pkgnames)
			@pkgnames = if pkgnames.is_a? Array
				pkgnames
			else
				[pkgnames]
			end
		end
		def get
			cmd = "pkg-config --libs " + @pkgnames.join(" ")
			# TODO - do better parsing here
			@res ||= `#{cmd}`.split(" ")
		end
	end
	class Flags < Array
		def initialize(*x)
			super(x.length) { |i| x[i] }
		end
		def get
			inject([]) { |o,f| o+f.get }
		end
	end
	class BuilderSettings
		attr_reader :flags
		def initialize(flags)
			@flags = flags
		end
	end
	class CommonSettings
		attr_reader :cc, :cxx, :ld
		def initialize
			@cc = newEmptySettings
			@cxx = newEmptySettings
			@ld = newEmptySettings
		end
		def newEmptySettings
			Hash.new { |hash,key|
				s = BuilderSettings.new(Flags.new())
				hash[key] = s
				s
			}
		end
	end
end
