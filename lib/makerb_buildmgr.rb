#!/usr/bin/ruby

module MakeRb
	class BuildMgr
		class LockedException < Exception
		end
		class Job
			attr_accessor :pid, :pipe, :out, :builder, :cmd
			def initialize(cmd_, pid_, pipe_, builder_)
				@pid = pid_
				@pipe = pipe_
				@out = ""
				@builder = builder_
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
		
		attr_reader :jobs, :pf_build, :pf_host, :pf_target, :settings, :builders, :resources, :builddir, :root
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
							puts "The above build process suceeded, but target is still outdated/nonexistent"
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
				if(target.builder == nil)
					throw "target #{target.name} doesn't have a builder"
				end
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
					r
				}
				builders = Array.new(step.length)
				for j in 0...step.length
					classes[i].new(pf, self, nil, step[j], nextstep[j])
				end
				
				step = nextstep
				
				i = i + 2
			end
			
			step
		end
		def join(pf,bclass,eclass,step,*args)
			last = eclass.new(self, *args)
			builder = bclass.new(pf, self, nil, step, last)
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
			@root = Pathname.new(File.dirname($0))
			@builddir = Pathname.new(opts[:builddir]) + (if settings.debug then "debug" else "release" end)
			
			['build','host','target'].each { |type|
				# Get the platform
				p = opts[type]
				pf = MakeRb::Platform.get(p)
				instance_variable_set("@pf_#{type}", pf)
				
				# Set the toolchain
				clname = opts["#{type}-compiler"]
				if(clname != nil)
					tc = MakeRbCCxx::toolchains[clname]
					if(tc == nil)
						raise "`#{clname}' is not a valid compiler"
					end
					pf.settings.def_toolchain = tc
				end
				
				# Get debug flag
				pf.settings.debug = opts["#{type}-debug"]
				
				# Set the flags
				['cc','cxx','ld'].each { |tool|
					flags = opts["#{type}-#{tool}flags"]
					if(flags != nil)
						# TODO: better parsing
						flags = flags.split(" ").map { |str| MakeRb::StaticFlag.new(str) }
						
						pf.settings.method(tool).call().specific[pf.settings.def_toolchain].flags.concat(flags)
					end
				}
			}
			
			
			block.call(self)
			@resources.each { |r| r.initialize2 }
			
			if (ARGV.size == 1 && ARGV[0] == "clean")
				@resources.each { |r|
					if(r.is_a? Generated)
						r.clean
					end
				}
				MakeRb.removeEmptyDirs(@builddir)
				0
			else
				@builddir.mkpath
				targets = if(ARGV.empty?)
					puts "No targets specified; building everything"
					@resources.select { |t| t.is_a?(Generated) }
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
		def <<(r)
			if(r.is_a? Resource)
				@resources << r
			else
				@builders << r
			end
		end
		def [](crit)
			i = @resources.index { |r| r.match_soft(crit) }
			if i == nil
				return nil
				i = @resources.index { |r| r.match_hard(crit) }
				if(i == nil)
					nil
				else
					@resources[i]
				end
			else
				@resources[i]
			end
		end
		def effective(p)
			@root + p
		end
	end
end
