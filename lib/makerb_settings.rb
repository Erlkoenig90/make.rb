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
		def initialize(x=[])
			super(x.length) { |i|
				if(x[i].is_a?(String))
					StaticFlag.new(x[i])
				else
					x[i]
				end
			}
		end
		def get
			inject([]) { |o,f| o+f.get }
		end
		def clone
			map { |f| f.clone }
		end
	end
	class BuilderSettings
		attr_reader :flags
		def initialize(flags=nil)
			@flags = if(flags == nil)
				Flags.new()
			else
				flags
			end
		end
		def clone
			BuilderSettings.new(flags.clone)
		end
	end
	class ToolSettings
		attr_accessor :specific
		def initialize(spec = nil)
			@specific = spec
			if(@specific == nil)
				@specific = Hash.new { |hash, key|
					s = BuilderSettings.new(Flags.new())
					hash[key] = s
					s
				}
			else
				if(@specific.is_a?(Hash))
					@specific.default_proc= proc do |hash,key|
						s = BuilderSettings.new(Flags.new())
						hash[key] = s
						s
					end
				end
			end
		end
		def clone
			ToolSettings.new(@specific.clone)
		end
	end
	class CompilerSettings < ToolSettings
		attr_accessor :includes
		def initialize(*x)
			super(*x)
			@includes = []
		end
		def clone
			s = CompilerSettings.new(specific.clone)
			s.includes=includes.clone
			s
		end
	end
	class LinkerSettings < ToolSettings
		attr_accessor :libraries
		def initialize(*x)
			super(*x)
			@libraries = []
		end
		def clone
			s = LinkerSettings.new(specific.clone)
			s.libraries = libraries.clone
			s
		end
	end
	class CommonSettings
		attr_accessor :cc, :cxx, :ld, :def_toolchain, :debug
		def initialize(c=nil, cx=nil, l=nil, def_tc=nil)
			@cc = c || CompilerSettings.new
			@cxx = cx || CompilerSettings.new
			@ld = l || LinkerSettings.new
			
			@def_toolchain = def_tc || MakeRbCCxx::toolchains["gcc"]
			@debug = false
		end
		def clone
			CommonSettings.new(cc.clone, cxx.clone, ld.clone, def_toolchain)
		end
	end
end
