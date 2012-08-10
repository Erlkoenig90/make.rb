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
		def clone
			map { |f| f.clone }
		end
	end
	class BuilderSettings
		attr_reader :flags
		def initialize(flags)
			@flags = flags
		end
		def clone
			BuilderSettings.new(flags.clone)
		end
	end
	class CommonSettings
		attr_accessor :cc, :cxx, :ld, :def_compiler, :def_linker
		def initialize(c=nil, cx=nil, l=nil, def_cmp=nil, def_ld=nil)
			@cc = if(c == nil) then newEmptySettings else c end
			@cxx = if(cx == nil) then newEmptySettings else cx end
			@ld = if(l == nil) then newEmptySettings else l end
			
			@def_compiler = if(def_cmp == nil) then MakeRbCCxx::GCC else def_cmp end
			@def_linker = if(def_linker == nil) then MakeRbCCxx::GCCLinker else def_linker end
		end
		def newEmptySettings
			Hash.new { |hash,key|
				s = BuilderSettings.new(Flags.new())
				hash[key] = s
				s
			}
		end
		def clone
			CommonSettings.new(cc.clone, cxx.clone, ld.clone, def_compiler, def_linker)
		end
	end
end
