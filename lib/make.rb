#!/usr/bin/env ruby

require 'pathname'
require 'optparse'
require 'trollop'
require 'rbconfig'

require 'makerb_settings'
require 'makerb_platform'

module MakeRb
	def MakeRb.isWindows
		@@is_windows ||= (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
	end
	def MakeRb.nullFile
		if(isWindows)
			"NUL"
		else
			"/dev/null"
		end
	end
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

	class Resource
		attr_accessor :builder, :buildMgr
		def initialize(mgr)
			@builder = nil
			@buildMgr = mgr
		end
		def name
			raise "Resource#name must be overriden!"
		end
	end
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
		def preUseDo
		end
		def postUseDo
		end
	end
	module Generated
		attr_reader :locked
		def initialize(*x)
			@locked = false
			super(*x)
		end
		
		def lock
			if(@locked)
				raise name + " is already locked";
			end
			@locked = true
		end
		def unlock
			if(!@locked)
				raise name + " is not locked";
			end
			@locked = false
		end
		
		def preBuild
		end
		def postBuild
		end
	end
	class FileRes < Resource
		include Usable
		
		attr_reader :name, :filename
		def initialize(mgr, fname)
			if(!fname.is_a?(Pathname))
				@name = File.basename(fname)
				fname = Pathname.new(fname)
			else
				@name = fname.basename.to_s
			end
			if(is_a?(Generated))
				fname = mgr.builddir + fname
			end
			@filename = fname
			super(mgr)
		end
		def rebuild?(other)
			if(!other.is_a?(FileRes))
				raise other.name + " is not a FileRes"
			end
			own = begin
				File.mtime(filename)
			rescue
				Time.at(0)
			end
			File.mtime(other.filename) >= own
		end
		def makePath
			filename.dirname.mkpath
		end
		def clean
			puts "rm -f \"" + @filename.to_s + "\""
			begin
				@filename.unlink
			rescue
			end
		end
	end
	class Builder
		attr_reader :sources, :targets, :platform, :buildMgr, :flags
		def initialize(pf, mgr, fl, src,t)
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

			@platform = pf
			@buildMgr = mgr
			if(fl == nil)
				@flags = MakeRb::Flags.new()
			else
				@flags = fl
			end
		end
		def rebuild?
			@targets.inject(false) { |old,target|
				old || @sources.inject(false) { |old2,source|
					old || target.rebuild?(source)
				}
			}
		end
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
		def buildDo
			raise "Builder#buildDo has to be overriden!"
		end
		def locked
			targets.inject(false) { |o,t| (o || t.locked) }
		end
		def lock
			targets.each { |t| t.lock }
		end
		def unlock
			targets.each { |t| t.unlock }
		end
	end
	class BuildMgr
		class LockedException < Exception
		end
		class Job
			attr_accessor :pid, :pipe, :out, :builder, :cmd
			def initialize(cmd_, pid_, pipe_, buider_)
				@pid = pid_
				@pipe = pipe_
				@out = ""
				@builder = buider_
				@cmd = cmd_
			end
			def read(force = false)
				if(force)
					@out << @pipe.read
				else
					r = 0
					begin
						if(!(@pipe.eof?))
							str = @pipe.read_nonblock(8*1024)
							r = str.length
							@out << str
						end
					end while r > 0 && !(@pipe.eof?)
				end
			end
			def eof?
				@pipe.eof?
			end
		end
		
		attr_reader :jobs, :pf_build, :pf_host, :pf_target, :settings, :builders, :resources, :builddir
		def initialize
			@settings = CommonSettings.new	# Project specific settings
			
			@builders = []
			@resources = []
			@pf_build = nil
			@pf_host = nil
			@pf_target = nil
			@debug = false
			@keepgoing = false
			@builddir = nil
		end
		def build(targets)
			procs = []
			
			run = true
			while(run)
				if(@debug) then puts "== ITERATION ==" end
				# Start new tasks
				while(procs.length < @jobs || @jobs == 0)
					builder = nil
					locked = false
					targets.each { |target|
						begin
							builder = find(target)
						rescue LockedException
							locked = true
						end
						if (builder != nil)
							break
						end
					}
					if(builder == nil)
						if(@debug) then puts "Nothing to build found" end
						break
					else
						builder.lock
						res = builder.build
						if(res != nil)
							proc = Job.new(res[0], res[1], res[2], builder)
							puts proc.cmd.join(" ")
							procs << proc
						end
					end
				end
				
				if(procs.count == 0)
					puts "Nothing to do anymore."
					break
				end
				
				# Wait for input
				fds = procs.map { |j| j.pipe }

				if(fds.length == 0)
					puts "Error: fds.length = 0. jcount = " + jcount.to_s
					exit
				end
				
				if(@debug) then $stdout.write "==SELECT== " end
				before = Time.now
				IO.select(fds)
				delay = Time.now - before
				if(@debug) then puts delay.to_s end
				
				forcewait = false
				procs.delete_if { |proc|
					# Read input data
					proc.read(forcewait)
					
					# Exited or force wait
					if(forcewait || proc.eof?)
						begin
							Process.waitpid(proc.pid)
						end while (!($?.exited?))
						
						if($?.exitstatus != 0)
							puts "Command failed:"
							puts proc.cmd.join(" ")
							puts proc.out
							if(!@keepgoing)
								run = false
								forcewait = true
							end
							@exitcode = 1
						elsif(proc.builder.rebuild?)
							puts proc.cmd.join(" ")
							puts "The above build process suceeded, but target is still outdated"
							if(!@keepgoing)
								run = false
								forcewait = true
							end
							@exitcode = 1
						else
							proc.builder.unlock
						end
						true
					else
						false
					end
				}
			end
		end
		def find(target,depth=0)
			indent = ("  "*depth)
			if(@debug) then puts indent + "find(" + target.name + ")" end
			if(target.is_a?(Generated))
				if(target.builder.locked)
#					puts indent + "locked"
					raise LockedException.new
				else
					found = nil
					ex = nil
					target.builder.sources.each { |s|
						begin
							found = find(s,depth+1)
						rescue LockedException
							ex = $!
						end
						
						if(found != nil)
							break
						end
					}
					if(ex != nil && found == nil)
						raise ex
					end
					if(found == nil)
						if(target.builder.rebuild?)
							found = target.builder
						end
					end
					found
				end
			else
				nil
			end
		end
		
		def newchain(pf,classes,args)
			step = args.map {|n| classes[0].new(self, n) }
			chain(pf,classes[1..-1],step)
		end
		def chain(pf,classes,step)
			i = 0
			while i+1 < classes.length
				nextstep = step.map { |s|
					r = classes[i+1].auto(s)
					@resources << r
					r
				}
				builders = Array.new(step.length)
				for j in 0...step.length
					@builders << classes[i].new(pf, self, nil, step[j], nextstep[j])
				end
				
				step = nextstep
				
				i = i + 2
			end
			
			step
		end
		def join(pf,bclass,eclass,step,*args)
			last = eclass.new(self, *args)
			builder = bclass.new(pf, self, nil, step, last)
			@builders << builder
			@resources << last
			last
		end
		def run(&block)
			@pf_build = Platform.native.clone
			@pf_host = Platform.native.clone
			@pf_target = Platform.native.clone
			
#				opts.banner = "Usage: #{$0} [options] [targets]"
#					puts 'Possible compiler toolchains to specify:'
#					MakeRbCCxx.compilers.each { |key,val|
#						puts "\t" + key + "\t\t" + val[0];
#					}
			opts = Trollop::options {
				opt :jobs, 'Number of jobs to run simultaneously, 0 for infinite', :short => '-j', :default => 1
				opt "build", 'Specify the platform we are compiling on.', :default => 'native'
				opt "host", 'Specify the platform the compiled program will run on.', :default => 'native'
				opt "target", 'Specify the platform the compiled program will produce code for; only useful for compilers.', :default => 'native'
				opt :make_debug, 'Show debug output of the build algorithm', :default => false
				opt :debug, 'Enable debugging on all platforms', :default => false
				opt :keep_going, 'Don\'t abort on error, but run as many tasks as possible', :default => false, :short => '-k'
				opt :builddir, 'Store generated files in this directory', :default => 'build'
				
				['build','host','target'].each { |type|
					opt "#{type}-compiler", "Specify the compiler+linker toolchain to use for the `#{type}\' platform. See below for possible values", :type => :string
					
					opt "#{type}-debug", "Enable debugging for the `#{type}\' platform.", :default => false
					
					['cc','cxx','ld'].each { |tool|
						opt "#{type}-#{tool}flags", "Specify #{tool} flags for use on the `#{type}' platform.", :type => :string
					}
				}

			}
			
			@jobs = opts[:jobs]
			@debug = opts[:make_debug]
			@keepgoing = opts[:keep_going]
			settings.debug = opts[:debug]
			@builddir = Pathname.new(opts[:builddir]) + (if settings.debug then "debug" else "release" end)
			
			['build','host','target'].each { |type|
				# Get the platform
				p = opts[type]
				pf = MakeRb::Platform.get(p)
				instance_variable_set("@pf_#{type}", pf)
				
				# Set the compiler
				clname = opts["#{type}-compiler"]
				if(clname != nil)
					tc = MakeRbCCxx::compilers[clname]
					if(tc == nil)
						raise "`#{clname}' is not a valid compiler"
					end
					pf.settings.def_compiler = tc[1]					
					pf.settings.def_linker = tc[2]
				end
				
				# Get debug flag
				pf.settings.debug = opts["#{type}-debug"]
				
				# Set the flags
				['cc','cxx','ld'].each { |tool|
					flags = opts["#{type}-#{tool}flags"]
					if(flags != nil)
						# TODO: better parsing
						flags = flags.split(" ").map { |str| MakeRb::StaticFlag.new(str) }
						
						klass = if(tool == 'ld') then pf.settings.def_linker else pf.settings.def_compiler end
						pf.settings.method(tool).call().specific[klass].flags.concat (flags)
					end
				}
			}
			
			
			block.call(self)
			
			if (ARGV.size == 1 && ARGV[0] == "clean")
				@resources.each { |r|
					r.clean
				}
				MakeRb.removeEmptyDirs(@builddir)
				0
			else
				@builddir.mkpath
				targets = if(ARGV.empty?)
					puts "No targets specified; building everything"
					@resources
				else
					ARGV.map { |n|
						i = @resources.index { |r| r.name == n }
						if(i == nil)
							raise "Target `#{n}' not found!"
						end
						@resources[i]
					}
				end
				puts "Building targets: " + targets.map {|t| t.name }.join(", ")
				@exitcode = 0
				build(targets)
				@exitcode
			end
		end
		def BuildMgr.run(&block)
			mgr = BuildMgr.new
			mgr.run(&block)
		end
	end
end

require 'makerb_binary'
require 'makerb_ccxx'

