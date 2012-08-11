#!/usr/bin/env ruby

require 'pathname'
require 'optparse'
require 'settings.rb'
require 'platform.rb'
require 'trollop'
require 'rbconfig'

# TODO: Keep-going


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

	class Resource
		attr_accessor :builder
		def initialize
			@builder = nil
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
		def initialize(fname)
			if(!fname.is_a?(Pathname))
				@name = File.basename(fname)
				fname = Pathname.new(fname)
			else
				@name = fname.basename.to_s
			end
			@filename = fname
			super()
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
			def initialize()
				@pid = -1
				@pipe = nil
				@out = ""
				@builder = nil
				@cmd = nil
			end
			def set(cmd, pid, pipe, builder)
				@cmd = cmd
				@pid = pid
				@pipe = pipe
				@builder = builder
				@out = ""
			end
			def reset
				@cmd = nil
				@pid = -1
				@out = nil
				@pipe.close
				@builder = nil
			end
			def isset
				@pid != -1
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
		
		attr_reader :jobs, :pf_build, :pf_host, :pf_target, :settings, :builders, :resources
		def initialize
			@settings = CommonSettings.new	# Project specific settings
			
			@builders = []
			@resources = []
			@pf_build = nil
			@pf_host = nil
			@pf_target = nil
			@debug = false
		end
		def build(targets)
			procs = Array.new(@jobs) { |i| Job.new }
			jcount = 0
			
			run = true
			while(run)
				if(@debug) then puts "== ITERATION ==" end
				# Start new tasks
				while(jcount < procs.length)
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
						if(!locked)
							run = false
						else
							if(jcount == 0)
								puts "Error: jcount = 0, but locks where found"
							end
						end
						break
					else
						builder.lock
						res = builder.build
#						puts "bla"
						if(res != nil)
							jcount += 1
							for i in 0...procs.length
								if(!procs[i].isset)
									procs[i].set(res[0], res[1], res[2], builder)
									puts "[" + i.to_s + "] " + procs[i].cmd.join(" ")
									break
								end
							end
						end
					end
				end
				
				if(jcount == 0)
					puts "Nothing to do anymore."
					break
				end
				
				# Wait for input
				fds = procs.select{ |j| j.isset }.map { |j| j.pipe }

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
				for i in 0...procs.length
					if(procs[i].isset)
						# Read input data
						procs[i].read(forcewait)
						
						# Exited or force wait
						if(forcewait || procs[i].eof?)
							begin
								Process.waitpid(procs[i].pid)
							end while (!($?.exited?))
							
							if($?.exitstatus != 0)
								puts "Command failed:"
								puts procs[i].cmd.join(" ")
								puts procs[i].out
								run = false
								forcewait = true
							end
							if(procs[i].builder.rebuild?)
								puts procs[i].cmd.join(" ")
								puts "The above build process suceeded, but target is still outdated; cancelling build"
								run = false
								forcewait = true
							end
							
							procs[i].builder.unlock
							procs[i].reset
							jcount -= 1
						end
					end
				end
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
			step = args.map {|n| classes[0].new(n) }
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
			last = eclass.new(*args)
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
				opt :jobs, 'Number of jobs to run simultaneously', :short => '-j', :default => 1
				opt "build", 'Specify the platform we are compiling on.', :default => 'native'
				opt "host", 'Specify the platform the compiled program will run on.', :default => 'native'
				opt "target", 'Specify the platform the compiled program will produce code for; only useful for compilers.', :default => 'native'
				opt :make_debug, 'Show debug output of the build algorithm', :default => false
				
				['build','host','target'].each { |type|
					opt "#{type}-compiler", "Specify the compiler+linker toolchain to use for the `#{type}\' platform. See below for possible values", :type => :string
					
					['cc','cxx','ld'].each { |tool|
						opt "#{type}-#{tool}flags", "Specify #{tool} flags for use on the `#{type}' platform.", :type => :string
					}
				}

			}
			
			@jobs = opts[:jobs]
			@debug = opts[:make_debug]
			['build','host','target'].each { |type|
				# Get the platform
				p = opts[type]
				pf = MakeRb.platforms[p]
				if(pf == nil)
					raise "Platform `#{p}' not found."
				end
				pf = pf.clone
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
				
				# Set the flags
				['cc','cxx','ld'].each { |tool|
					flags = opts["#{type}-#{tool}flags"]
					if(flags != nil)
						# TODO: better parsing
						flags = flags.split(" ").map { |str| MakeRb::StaticFlag.new(str) }
						
						klass = if(tool == 'ld') then pf.settings.def_linker else pf.settings.def_compiler end
						pf.settings.method(tool).call()[klass].flags.concat (flags)
					end
				}
			}
			
			
			block.call(self)
			
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
			build(targets)
		end
		def BuildMgr.run(&block)
			mgr = BuildMgr.new
			mgr.run(&block)
		end
	end
end

require 'makerb_binary'
require 'makerb_ccxx'

