#!/usr/bin/env ruby

module MakeRb
	def MakeRb.collectDepsG(ary,lsym,lcsym)
		f = ary.map() { |el|
			if(el.used)
				[]
			else
				el.used = true
			
				[el] + if(el.respond_to?(:deps))
					collectDepsG(el.deps, lsym, lcsym)
				else
					[]
				end + if(el.respond_to?(:settings))
					collectDepsG(el.settings.send(lsym).send(lcsym),lsym,lcsym)
				else
					[]
				end
			end
		}.flatten
		f.each { |el| el.used = false }
		f
	end
	def MakeRb.collectIDeps(ary,cx)
		MakeRb.collectDepsG(ary,if cx then :cxx else :cc end, :includes)
	end
	def MakeRb.collectLDeps(ary,cx)
		MakeRb.collectDepsG(ary,if cx then :cxx else :cc end, :libraries)
	end
	class Library
		attr_accessor :used
		def initialize
			@used = false
		end
	end
	class SystemLibrary < Library
		attr_reader :name
		def initialize(name)
			@name = name
		end
	end
	class LibraryFile < Library
		attr_reader :path
		def initialize(path_)
			@path = path_
		end
	end
	class IncludeDir
		attr_accessor :used, :path
		def initialize(path_)
			@used = false
			@path = if(path_.is_a?(Pathname)) then path_ else Pathname.new(path_) end
		end
	end
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
		def clFor(x)
			if(x) then cxx else cc end
		end
	end
end
