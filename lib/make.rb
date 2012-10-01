#!/usr/bin/env ruby

require 'rubygems'
require 'pathname'
require 'optparse'
require 'trollop'
require 'rbconfig'

require 'makerb_settings'
require 'makerb_platform'
require 'makerb_ext'

module MakeRb
	# Checks whether we are currently running on Windows. The result does/should not affect the built files,
	# and is just to determine how to run programs, process pathnames etc.
	# @return [Boolean] whether we are running windows
	def MakeRb.isWindows
		@@is_windows ||= (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
	end
	# @return [String] "NUL" for windows systems, "/dev/null" else. 
	def MakeRb.nullFile
		if(isWindows)
			"NUL"
		else
			"/dev/null"
		end
	end
	# Calls preUse on the given array, and if any of them fails, calls postUse
	# @param [Array] arr an array of {Resource}s
	def MakeRb.safePreUse(arr)
		for i in 0...arr.size
			begin
				arr[i].preUse
			rescue
				for j in 0...i
					arr[j].postUse
				end
				raise
			end
		end
	end
	# Calls preBuild on the given array, and if any of them fails, calls postBuild
	# @param [Array] arr an array of {Resource}s
	def MakeRb.safePreBuild(arr)
		for i in 0...arr.size
			begin
				arr[i].preBuild
			rescue
				for j in 0...i
					arr[j].postBuild
				end
				raise
			end
		end
	end
	# Recursively removes path and all its children which are empty directories.
	# @param [Pathname] path The directory to remove
	def MakeRb.removeEmptyDirs(path)
		if(path.directory?)
			if(path.children.inject(true) { |o,c| o && removeEmptyDirs(c) })
				puts "rmdir \"" + path.to_s + "\""
				path.rmdir
				true
			else
				false
			end
		else
			false
		end
	end
	# Parses the given shell-escaped string into an array of arguments
	# Is the inverse of {buildCmd}
	# @param [String] flagstring
	# @return [Array]
	def MakeRb.parseFlags(flagstring)
		# TODO - better parsing here
		flagstring.split(" ")
	end
	# Escapes the given array of command line arguments into a string suitable for shell execution.
	# Is the inverse of {parseFlags}
	# @param [Array] args
	# @return [String]
	def MakeRb.buildCmd(args)
		# TODO - escaping here
		args.join(" ")
	end
	# Adds a newline to the end of the given string, if it has none and is not empty
	# @param [String] str
	# @return [String]
	def MakeRb.ensureNewline(str)
		str.empty? ? "" : (str[-1] == "\n" ? str : str + "\n")
	end
	# Represents a data set to be used by builders. In most cases, the derived class {FileRes} will be used. This
	# is the abstract form, which could also represent e.g. a database.
	class Resource
		attr_accessor :builder, :buildMgr
		# @param [BuildMgr] mgr
		def initialize(mgr)
			@builder = nil
			@buildMgr = mgr
			mgr << self
		end
		# To be overwritten by derived classes. Should return a string which identifies this resource uniquely.
		# @return [String]
		def name
			raise "Resource#name must be overriden!"
		end
		# To be overwritten by derived classes, if needed. Called by the BuildMgr after all the user-defined
		# {Builder} and {Resource} objects have been created.
		def initialize2
		end
		# To be overwritten by derived classes, if needed. Used for searching {Resource}s.
		def match(m)
			false
		end
		# Result is added to a {Builder}'s specialisations when this {Resource} is used as one of its destionations. 
		def destSpecialisations
			SettingsKey[]
		end
		# Result is added to a {Builder}'s specialisations when this {Resource} is used as one of its sources. 
		def srcSpecialisations
			SettingsKey[]
		end
		# To be overwritten by derived classes. Tells the {BuildMgr} whether this resource is out of date and should be re-built.
		# @param [Resource] other The resource to compare this {Resource} to.
		# @return [Boolean]
		def rebuild?(other)
			raise "No Resource#rebuild? specified"
		end
		# This can be overwritten by derived classes, if there's a faster method to match against a criterium, but
		# which does not always return true when it should to. Used to speed up searching for {Resource}s.
		def matchSoft(m)
		end
		# Derived classes can implement this for searching for {Resource}s.
		# @return [Boolean]
		def match(m)
			false
		end
	end
	# Identifies a {Resource} (to be used as a mixin) which can be used by {Builder}s. Provides refcounting
	# so this {Resource} can simultaneously be used by multiple {Builder}s, by calling the {Usable#preUseDo}
	# and {Usable#postUseDo} methods, while avoiding superfluous calls.
	module Usable
		attr_reader :refcount
		def initialize(*x)
			@refcount = 0
			super(*x)
		end
		def preUse
			@refcount += 1
			if(@refcount == 1)
				preUseDo
			end
		end
		def postUse
			@refcount -= 1
			if(@refcount == 0)
				postUseDo
			end
		end
		# To be defined by including classes - called before this resource is used by a {Builder}. Might be used
		# for transparent pre-processing. Is only called once in the case that this resource is used by multiple
		# {Builder}s simultaneously.
		def preUseDo
		end
		# To be defined by including classes - called after this resource is used by a {Builder}. Might be used
		# for transparent post-processing. Is only called once in the case that this resource is used by multiple
		# {Builder}s simultaneously.
		def postUseDo
		end
	end
	# To be used as a mixin for classes deriving from {Resource}. Marks a resource that is generated by a {Builder},
	# i.e. not manually created.
	module Generated
		attr_reader :locked
		def initialize(*x)
			@locked = false
			super(*x)
		end
		# Used by {BuildMgr}
		def lock
			if(@locked)
				raise name + " is already locked";
			end
			@locked = true
		end
		# Used by {BuildMgr}
		def unlock
			if(!@locked)
				raise name + " is not locked";
			end
			@locked = false
		end
		# To be implemented by deriving classes - called before the {Resource} will be generated
		def preBuild
		end
		# To be implemented by deriving classes - called after the {Resource} has been generated
		def postBuild
		end
	end
	# Marks a {Resource} which is not directly passed to a program launched by a {Builder}, but is implicitly
	# referenced. Allows to e.g. track dependencies of #include files, when these files aren't directly passed
	# to the compiler.   
	module ImplicitSrc
	end
	# Represents a {Resource} which is a file on the local file system.
	class FileRes < Resource
		include Usable
		
		attr_reader :name, :filename
		# @param [BuildMgr] mgr
		# @param [Pathname, String] fname
		def initialize(mgr, fname)
			if(fname.is_a?(String))
				@filename_str = fname
				fname = Pathname.new(fname)
			elsif(fname.is_a?(Pathname))
				@filename_str = fname.to_s
			else
				raise "Invalid argument for FileRes#initialize"
			end
			@name = fname.to_s
			# @filename_str is only used to speed up "match"
			if(is_a?(Generated))
				fname = mgr.builddir + fname
			end
			@filename = fname
			super(mgr)
		end
		# See {Resource#rebuild?}
		def rebuild?(other)
			if(!other.is_a?(FileRes))
				raise other.name + " is not a FileRes"
			end
			own = begin
				File.mtime(buildMgr.effective(filename))
			rescue
				Time.at(0)
			end
			res = File.mtime(other.buildMgr.effective(other.filename)) > own
#			puts "rebuild #{other.filename.to_s} -> #{filename.to_s} => #{res}"
#			if(res) then raise "test" end
			res
		end
		# Creates the directory of this file, if it does not already exist.
		def makePath
			buildMgr.effective(filename).dirname.mkpath
		end
		# Removes the file.
		def clean
			puts "rm -f \"" + @filename.to_s + "\""
			begin
				buildMgr.effective(@filename).unlink
			rescue
			end
		end
		# See {Resource#matchSoft}
		def matchSoft(m)
#			puts "match_soft: #{m} == #{@filename_str}"
#			p @filename_str
#			p m
			m.is_a?(String) && (m == @filename_str || ("./" + m) == @filename_str || m == ("./" + @filename_str))
		end
		# Tests whether this {FileRes} represents the file given by the parameter.
		# @param [Pathname,String] m
		def match(m)
			if(m.is_a?(Pathname))
				begin
#					false
					(filename.eql? m) || (filename.realdirpath == m.realdirpath)
				rescue
					false
				end
			else
#				false
				@filename_str == m || match_hard(Pathname.new(m))
			end
		end
		# Yields the Pathname to really be used on building (e.g. in the build directory). See {BuildMgr#effective}
		def effective
			buildMgr.effective(filename)
		end
	end
	# A {FileRes} that includes the {Generated} mixin.
	class GeneratedFileRes < FileRes
		include Generated
	end
	# Base class for builders. Derived classes should represent types of external programs that perform a
	# certain task (e.g. compiling C sources, like {MakeRbCCxx::Compiler}), and provide a general interface
	# for that (via the {SettingsMatrix}). These classes should then be used as base classes for concrete
	# implementations (e.g. {MakeRbCCxx::GCC}). These should provide the {Builder#buildDo} method, to launch
	# the external program.
	class Builder
		attr_reader :sources, :targets, :specialisations, :buildMgr
		# @param [BuildMgr] mgr
		# @param [SettingsKey] spec Specialisations to be used when querying settings for this builder
		# @param [Array] src The {Resource}s to be used as sources.
		# @param [Array] t The {Resource}s to be used as targets.
		def initialize(mgr, spec, src,t)
			if(!src.is_a?(Array))
				@sources = [src]
			else
				@sources = src
			end
			
			if(!t.is_a?(Array))
				@targets = [t]
			else
				@targets = t
			end
			@targets.each { |t| t.builder=self }

			@specialisations = spec
			@buildMgr = mgr
			
			mgr << self
		end
		# Tells the {BuildMgr} whether this {Builder} should be re-executed because any targets are outdated.
		# Calls {Resource#rebuild?} on every source-target combination.
		# @return [Boolean]
		def rebuild?
			@targets.inject(false) { |old,target|
				old || @sources.inject(false) { |old2,source|
					old2 || target.rebuild?(source)
				}
			}
		end
		# Called by {BuildMgr}. Calls the appropriate {Usable#preUse}, {Generated#postBuild} methods, calls
		# {Builder#buildDo} and uses its return value as the arguments to start the actual program. If
		# {Builder#buildDo} returns nil, it does nothing.
		def build
			MakeRb.safePreUse(@sources)
			begin
				MakeRb.safePreBuild(@targets)
			rescue
				@sources.each { |s| s.postUse }
				raise
			end
			
			begin
				cmd = buildDo
#				puts "spawning " + cmd.join(" ")
				if(cmd != nil)
					r, w = IO.pipe
					pid = spawn(*cmd, :out=>w, :err=>w, r=>:close, :in=>MakeRb.nullFile)
					w.close
					
					[cmd, pid, r]
				else
					nil
				end
			rescue
				@sources.each { |s| s.postUse }
				@targets.each { |s| s.postBuild }
				raise
			end
		end
		# To be implemented by deriving classes.
		# @return [Array] of String's, which are used as the program's arguments. The first one is the
		#   program's name, e.g.: ["gcc", "-c", "-o", "test.o", "test.c"]
		def buildDo
			raise "Builder#buildDo has to be overriden!"
		end
		# Used by {BuildMgr}
		def locked
			targets.inject(false) { |o,t| (o || t.locked) }
		end
		# Used by {BuildMgr}
		def lock
			targets.each { |t| t.lock }
		end
		# Used by {BuildMgr}
		def unlock
			targets.each { |t| t.unlock }
		end
	end
	# A builder that calls a block for {Builder#buildDo}. Used by the convenience API.
	class InlineBuilder < Builder
		def initialize(mgr, spec, src,t, block)
			super(mgr,spec,src,t)
			@buildBlock = block
		end
		def buildDo
			@buildBlock.call(sources, targets, specialisations)
		end
	end
end

require 'makerb_buildmgr'
require 'makerb_binary'
require 'makerb_ccxx'
require 'makerb_misc'

