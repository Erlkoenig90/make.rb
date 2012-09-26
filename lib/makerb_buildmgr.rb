#!/usr/bin/env ruby

#	Copyright © 2012, Niklas Gürtler
#	Redistribution and use in source and binary forms, with or without
#	modification, are permitted provided that the following conditions are
#	met:
#	
#	    (1) Redistributions of source code must retain the above copyright
#	    notice, this list of conditions and the following disclaimer. 
#	
#	    (2) Redistributions in binary form must reproduce the above copyright
#	    notice, this list of conditions and the following disclaimer in
#	    the documentation and/or other materials provided with the
#	    distribution.  
#	    
#	    (3) The name of the author may not be used to
#	    endorse or promote products derived from this software without
#	    specific prior written permission.
#	
#	THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
#	IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#	DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
#	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#	(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
#	SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
#	HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
#	STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
#	IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#	POSSIBILITY OF SUCH DAMAGE.

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
		
		attr_reader :jobs, :settings, :builders, :resources, :reshash, :builddir, :root, :mec, :typeKeys
		def initialize
			@builders = []
			@resources = []
			@reshash = {}
			@typeKeys = {:build => SettingsKey[], :host => SettingsKey[], :target => SettingsKey[]}
			@settings = nil
			@debug = false
			@keepgoing = false
			@builddir = nil
			@mec = nil
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
#				opts.banner = "Usage: #{$0} [options] [targets]"
#					puts 'Possible compiler toolchains to specify:'
#					MakeRbCCxx.compilers.each { |key,val|
#						puts "\t" + key + "\t\t" + val[0];
#					}
			namespaceDoObfuscator = typeKeys
			opts = Trollop::options {
				opt :jobs, 'Number of jobs to run simultaneously, 0 for infinite', :short => '-j', :default => 1
				opt "build", 'Specify the platform we are compiling on.', :default => 'native'
				opt "host", 'Specify the platform the compiled program will run on.', :default => 'native'
				opt "target", 'Specify the platform the compiled program will produce code for; only useful for compilers.', :default => 'native'
				opt :make_debug, 'Show debug output of the build algorithm', :default => false
				opt :debug, 'Enable debugging on all platforms', :default => false
				opt :keep_going, 'Don\'t abort on error, but run as many tasks as possible', :default => false, :short => '-k'
				opt :builddir, 'Store generated files in this directory', :default => 'build'
				
				namespaceDoObfuscator.each { |type,key|
					opt "#{type}-debug", "Enable debugging for the `#{type}\' platform.", :default => false
				}

			}
			
			@jobs = opts[:jobs]
			@debug = opts[:make_debug]
			@keepgoing = opts[:keep_going]
			@root = Pathname.new(File.dirname($0))
			@builddir = Pathname.new(opts[:builddir]) + (if opts[:debug] then "debug" else "release" end)
			
			typeKeys.each { |type, key|
				# Get the platform
				p = opts[type.to_s]
				key[:platform] = pf = MakeRb::Platform.get(p)
				
				# Use the default toolchain, which might come from the command line
				key[:toolchain] = pf.defToolchain || raise("No toolchain for `#{type}' specified and no default toolchain defined")
				
				# Get debug flag
				key[:debug] = opts[:debug] || opts["#{type}-debug"] || false
			}
			
			@settings = SettingsMatrix.build # the global settings blob. this has to come *after* querying (and possibly building) the platform objects.
			@mec = MakeRbExt::ExtManager.new(self)
#			@mlc["zlib"]
			
			block.call
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
			cv = MakeRbConv.new(mgr)
			mgr.run {
				cv.instance_eval(&block)
			}
		end
		def <<(r)
			if(r.is_a? Resource)
				@resources << r
				if(@reshash.include?(r.name))
					raise("There's already a resource with name `#{r.name}'")
				end
				@reshash[r.name] = r
			else
				@builders << r
			end
		end
		def [](name)
			@reshash[name]
		end
		def findRes(crit)
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
			if(p.absolute?) then p else @root + p end
		end
	end
end

class MakeRbConv
	class Rule
		attr_reader :name, :src, :dest, :builder, :specialisations, :block, :settings
		def initialize(name_, src_,dest_,builder_,spec,block_,settings_)
			@name = name_
			@src = src_
			@dest = dest_
			@builder = builder_
			@specialisations = spec
			@block = block_
			@settings = settings_
		end
	end
	attr_reader :buildMgr
	def initialize(mgr)
		@buildMgr = mgr
		@rules = {}
			
		mgr.typeKeys.each { |type,key|
			self.class.send(:define_method,type) {
				key
			}
		}
	end
	def rule(name,src,dest,*rest,&block)
		spec = MakeRb::SettingsKey[]
		builder = nil
		settings = MakeRb::Settings[]
		
		rest.each { |param|
			if((param.is_a?(Class) && param < MakeRb::Builder) || param.is_a?(Symbol))
				builder = param
			elsif(param.is_a?(MakeRb::SettingsKey))
				spec = spec + param
			elsif(param.is_a?(MakeRb::Settings))
				settings = settings + param
			else
				raise ""
			end
		}
		if(builder.is_a?(Symbol))
			if(!spec.include?(:toolchain))
				raise("Builder is symbolic, but not toolchain specialisations provided. You have to e.g. supply `host' so the appropriate builder can be found.")
			end
			tc = spec[:toolchain]
			if(!tc.respond_to?(builder) || (builder = tc.send(builder)) == nil)
				raise("Toolchain doesn't provice a tool for `#{builder}'")
			end
		end
		if (builder == nil && block == nil) then raise("No builder and no block specified!") end
		
		@rules[name] = Rule.new(name, src, dest, builder, spec, block, settings)
	end
	def dep(name, sparam, dparam = nil, options = {})
		r = @rules[name] || raise("No rule `#{name}' defined!")
		spec = r.specialisations
		if(options.include?(:spec))
			spec = spec + options[:spec]
		end
		
		if(!sparam.is_a?(Array)) then sparam = [sparam] end
		src = (0...sparam.length).map { |i|
			if(i >= r.src.length || r.src[i] == nil)
				res(sparam[i])
			else
				r.src[i].new(buildMgr, *sparam[i])
			end
		}
		if(!dparam.is_a?(Array)) then dparam = [dparam] end
		dest = (0...[r.dest.length, dparam.length].max).map { |i|
			if(i >= r.dest.length || r.dest[i] == nil)
				res(dparam[i])
			elsif((dparam == nil || i >= dparam.length || dparam[i] == nil) && r.dest[i].respond_to?(:auto))
				r.dest[i].auto(*src)
			else
				r.dest[i].new(buildMgr, *dparam[i])
			end
		}
		if(r.builder != nil)
			builders = [r.builder.new(buildMgr, spec, src, dest, *(options[:builder] || []))]
			if(r.block != nil)
				ret = r.block.call(src, dest, builder, *(options[:block] || []))
				if(ret.is_a?(Builder))
					builders << ret
				elsif(ret.is_a?(Array))
					builders.concat!(ret)
				end
			end
		elsif(r.block != nil)
			builders = r.block.call(src, dest, *(options[:builder] || []))
		else
			builders = []
		end
		settings = if(options.include?(:settings))
			options[:settings] + r.settings
		else
			r.settings
		end
		if(builders != nil && settings != nil && !settings.empty?)
			if(!builders.is_a?(Array)) then builders = [builders] end
			builders.each { |builder|
				@buildMgr.settings[MakeRb::SettingsKey[:builder => builder]]= settings
			}
		end
	end
	def ddep(name, *params)
		params.each { |param|
			dep(name, *param)
		}
	end
	def libs(key, *blocks)
		set = Set[]
		blocks.each { |block| block.call(@buildMgr.settings, key, set) }
		
		key + SettingsKey[:libraries => set.to_a]
	end
	def loadExt(*names)
		names.each { |name|
			@buildMgr.mec.load(name)
		}
	end
	def res(name)
		buildMgr[name] || raise("No resource called `#{name}' found")
	end
end