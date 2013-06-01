#!/usr/bin/env ruby

module MakeRb
	# The main object for building. It keeps the list of {Builder}s and {Resource}s, and has the algorithms
	# to find out when to run which builder. Also reads the command line arguments.
	class BuildMgr
		class LockedException < Exception
		end

		# Represents a running builder
		class Job
			attr_accessor :pid, :pipe, :out, :builder, :cmd, :strCmd
			def initialize(cmd_, pid_, pipe_, builder_, strCmd_)
				@pid = pid_
				@pipe = pipe_
				@out = ""
				@builder = builder_
				@cmd = cmd_
				@strCmd = strCmd_
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
			@verbose = false
			@mec = nil
		end

		# Builds the given targets.
		# @param [Array] targets
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
							proc = Job.new(res[0], res[1], res[2], builder, res [3])
							#							puts MakeRb.buildCmd(proc.cmd)
							procs << proc
						else
							builder.unlock
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
							puts MakeRb.buildCmd(proc.cmd)
							$stdout.write MakeRb.ensureNewline(proc.out)
							if(!@keepgoing)
								run = false
								forcewait = true
							end
							@exitcode = 1
						elsif(proc.builder.rebuild?)
							puts "This build process suceeded, but target is still outdated/nonexistent:"
							puts MakeRb.buildCmd(proc.cmd)
							$stdout.write MakeRb.ensureNewline(proc.out)
							if(!@keepgoing)
								run = false
								forcewait = true
							end
							@exitcode = 1
						else
							puts proc.strCmd
							$stdout.write MakeRb.ensureNewline(proc.out)
							proc.builder.unlock
						end
						true
					else
						false
					end
				}
			end
		end

		# Finds a target to build next
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
		
		# TODO fix doc
		# To be called by the script. Parses the command line arguments, sets up the build environment, calls the
		# block and starts the build process.
		# @param [Proc] block The block should define the {Builder}s and {Resource}s for the program.
		def run(decl)
			#				opts.banner = "Usage: #{$0} [options] [targets]"
			#					puts 'Possible compiler toolchains to specify:'
			#					MakeRbCCxx.compilers.each { |key,val|
			#						puts "\t" + key + "\t\t" + val[0];
			#					}
			namespaceDeObfuscator = typeKeys
			opts = Trollop::options {
				opt :jobs, 'Number of jobs to run simultaneously, 0 for infinite', :short => '-j', :default => 1
				opt "build", 'Specify the platform we are compiling on.', :default => 'native'
				opt "host", 'Specify the platform the compiled program will run on.', :default => 'native'
				opt "target", 'Specify the platform the compiled program will produce code for; only useful for compilers.', :default => 'native'
				opt :make_debug, 'Show debug output of the build algorithm', :default => false
				opt :debug, 'Enable debugging on all platforms', :default => false
				opt :keep_going, 'Don\'t abort on error, but run as many tasks as possible', :default => false, :short => '-k'
				opt :builddir, 'Store generated files in this directory', :default => 'build'
				opt :verbose, 'Output some information', :default => false, :short => '-v'

				namespaceDeObfuscator.each { |type,key|
					opt "#{type}-debug", "Enable debugging for the `#{type}\' platform.", :default => false
				}

			}

			@jobs = opts[:jobs]
			@debug = opts[:make_debug]
			@keepgoing = opts[:keep_going]
			@root = Pathname.new(File.dirname($0))
			@builddir = Pathname.new(opts[:builddir]) + (if opts[:debug] then "debug" else "release" end)
			@verbose = opts[:verbose]

			typeKeys.each { |type, key|
				# Get the platform
				p = opts[type.to_s]
				key[:platform] = pf = MakeRb::Platform.get(p)
				
				# Use the default toolchain, which might come from the command line
				key[:toolchain] = pf.defToolchain || raise("No toolchain for `#{type}' specified and no default toolchain defined")

				# Get debug flag
				key[:debug] = opts[:debug] || opts["#{type}-debug"] || false
			}
#			@builddir = Pathname.new(opts[:builddir]) + (if opts[:debug] then "debug" else "release" end) +
#				(typeKeys.map {|t,k| t.to_s+"="+k[:platform].name }.join(","))

			@settings = SettingsMatrix.build # the global settings blob. this has to come *after* querying (and possibly building) the platform objects.
			@mec = MakeRbExt::ExtManager.new(@settings)
			
			if(@verbose)
				puts "Running on platform #{Platform.native.name}"
			end

			decl.declare
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
				if(@verbose)
					puts "Building targets: " + targets.map {|t| t.name }.join(", ")
				end
				@exitcode = 0
				build(targets)
				@exitcode
			end
		end
	
		# TODO fix doc
		# For using the convenience API (see {MakeRbConv}). Similar to {#run}, but the block will be executed
		# in the context of a {MakeRbConv} instance for using the {MakeRbConv#rule rule}, {MakeRbConv#dep dep}
		# etc. methods.
		# @param [Proc] block The block should define the {Builder}s and {Resource}s for the program using {MakeRbConv}'s methods
		def BuildMgr.run(&block)
			ImplDeclarations.new(block)
		end

		# Adds the given object to the {BuildMgr}'s knowledge, to make them available for building.
		# @param [Resource, Builder] r
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

		# Find {Resource}'s by their {Resource#name name}.
		# @return [Resource, nil]
		def [](name)
			@reshash[name]
		end

		# Find {Resource}'s using their {Resource#match match} and {Resource#matchSoft matchSoft} methods.
		# @return [Resource, nil]
		def findRes(crit)
			i = @resources.index { |r| r.matchSoft(crit) }
			if i == nil
				i = @resources.index { |r| r.match(crit) }
				if(i == nil)
					nil
				else
					@resources[i]
				end
			else
				@resources[i]
			end
		end

		# Calculates the real path of a file in the filesystem, possibly relative to the current working directory.
		# Currently prepends the current build dir to the path.
		def effective(p)
			p = if(p.is_a?(Pathname)) then p else Pathname.new(p) end
			if(p.absolute?) then p else @root + p end
		end
		# Returns the {SettingsMatrix#getSettings settings} for the platform we are currently running on
		def nativeSettings
			settings.nativeSettings
		end
	end
	# TODO doc
	class Declarations
		attr_reader :buildMgr, :conv
		def initialize
			@buildMgr = BuildMgr.new
			@conv = MakeRbConv.new(@buildMgr)
			@buildMgr.run(self)
		end
		def declare
			namespaceDeObfuscator = self
			@conv.instance_eval(&namespaceDeObfuscator.declarec)
		end
		def options
		end
	end
	# TODO doc
	class ImplDeclarations < Declarations
		def initialize(block)
			@implBlock = block
			super()
		end
		def declare
			conv.instance_eval(&@implBlock)
		end
	end
	def MakeRb.declare(&block)
		klass = Class.new(Declarations, &block)
		inst = klass.new
		if(isset($makerb_caller))
			
		end
	end
end

# The convenience API for {MakeRb::BuildMgr}.
class MakeRbConv
	# A rule defined by {#rule rule}
	class Rule
		attr_reader :name, :src, :dest, :builder, :specialisations, :block, :settings, :libs, :settingsM
		def initialize(name_, src_,dest_,builder_,spec,block_,settings_,libs_,sm_)
			@name = name_
			@src = src_
			@dest = dest_
			@builder = builder_
			@specialisations = spec
			@block = block_
			@settings = settings_
			@libs = libs_
			@settingsM = sm_
		end
	end
	attr_reader :buildMgr

	def initialize(mgr)
		@buildMgr = mgr
		@rules = {}
		@tprefix = nil

		mgr.typeKeys.each { |type,key|
			self.class.send(:define_method,type) {
				key
			}
		}
	end

	# Defines a rule for processing targets, whose exact files are to be defined via {#dep dep}.
	# @param [String] name The new rule's name.
	# @param [Array] src An array of classes (ruby Class objects) derived from {MakeRb::Resource}. Instances of these
	#   classes will be created using the parameters given to {#dep dep} and will be used as sources to the defined
	#   builder. Can be left empty when specifying explicit {MakeRb::Resource}'s to {#dep dep}
	# @param [Array] dest An array of classed (ruby Class objects) derived from {MakeRb::Resource}. Instances of these
	#   classes will be created using the parameters given to {#dep dep} and will be used as targets to the defined
	#   builder.
	# @param [Array] rest Array of unordered additional data. Can contain:
	#   * Zero or one of
	#     * a class derived from {MakeRb::Builder} to specify which type of builder to use
	#     * a ruby keyword. It will be sent(ruby send method) to the current {MakeRbCCxx::ClToolchain toolchain} instance
	#       to get the builder to use, e.g. :compiler or :linker.
	#   * {MakeRb::Settings} instances, to specify extra settings to apply to the generated {MakeRb::Builder}
	#   * {MakeRb::SettingsKey} instances, to specialize what settings will be used for the generated {MakeRb::Builder}s.
	#   * {MakeRbExt::LibProxyProc} instances (results of the {MakeRbExt::Library#where} method), to specify the libraries to be used
	#   * Zero or one {MakeRb::SettingsMatrix} instance which will be added to the main settings matrix, with the :builder key set
	#     to the generated {MakeRb::Builder} instance
	# @param [Proc] block If given, the block will be called upon invocation of {#dep dep} and can return an Array of {MakeRb::Builder}'s,
	#   instead of using a builder class or keyword in the rest parameter.
	# @return [Rule]
	def rule(name,src,dest,*rest,&block)
		spec = MakeRb::SettingsKey[]
		builder = nil
		settings = MakeRb::Settings[]
		libs = []
		sm = nil

		i = 4
		rest.each { |param|
			if((param.is_a?(Class) && param < MakeRb::Builder) || param.is_a?(Symbol))
				builder = param
			elsif(param.is_a?(MakeRb::SettingsKey))
				spec = spec + param
			elsif(param.is_a?(MakeRb::Settings))
				settings = settings + param
			elsif(param.is_a?(MakeRbExt::LibProxyProc))
				libs << param
			elsif(param.is_a?(MakeRb::SettingsMatrix))
				sm = param
			else
				raise "rule: Don't know how to use parameter #{i} of type #{param.class}: " + param.inspect
			end
			i += 1
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

		@rules[name] = Rule.new(name, src, dest, builder, spec, block, settings, libs, sm)
	end

	# Uses the given parameters to create {MakeRb::Resource resource}s and {MakeRb::Builder builder}s of the classes
	# specified via the given rule, connects them appropriately and feeds them to the {MakeRb::BuildMgr}.
	# @param [String] name the name of the rule to be used
	# @param [Array] sparam an array of arrays of arguments to pass to the constructors of the {MakeRb::Resource resource}s
	#   used as soucres to the builder. If the constructors take only one argument, sparam can also be an Array of the arguments.
	#   If there is only one source whose constructor takes only one argument, sparam can be this only argument.
	#   If no {MakeRb::Resource Resource} classs have been specified via the {#rule rule} method, sparam can also
	#   contain names of resources to be used, or actual {MakeRb::Resource Resource} objects (the target resources
	#   are returned by this method)
	# @param [Array] dparam Like sparam, just for the targets of the builers. This array can also be empty or left out,
	#   in this case the respective 'auto' class method of the {MakeRb::Resource} class will be used.
	# @param [hash] options Various options. Possible key-value pairs:
	#   * :libs => an Array of {MakeRbExt::LibProxyProc} instances (results of the {MakeRbExt::Library#where} method), to specify the libraries to be used
	#   * :builder => an Array of additional arguments passed to the {MakeRb::Builder}'s constructor.
	#   * :spec => Additional specialisations to be used for the created {MakeRb::Builder}.
	#   * :settings => Additional settings to attach to the created builder.
	#   * :block => If the rule has both a block and a {MakeRb::Builder} class specified, the array passed via :block
	#     will be passed to the rule's block as additional parameters.
	# @return [Array] the array of generated targets, can be used for the sparam parameter of subsequent {#dep dep} calls.
	def dep(name, sparam, dparam = nil, options = {})
		r = @rules[name] || raise("No rule `#{name}' defined!")
		spec = r.specialisations
		if(options.include?(:spec))
			spec = spec + options[:spec]
		end

		if(!sparam.is_a?(Array)) then sparam = [sparam] end
		src = (0...sparam.length).map { |i|
			if(i >= r.src.length || r.src[i] == nil)
				if(sparam[i].is_a?(Resource)) then sparam[i] else res(sparam[i]) end
			else
				mkRes(r.src[i], spec, *sparam[i])
			end
		}
		if(!dparam.is_a?(Array) && dparam != nil) then dparam = [dparam] end
		dest = (0...[r.dest.length, if dparam == nil then 0 else dparam.length end].max).map { |i|
			if(i >= r.dest.length || r.dest[i] == nil)
				if(dparam[i].is_a?(Resource)) then dparam[i] else res(dparam[i]) end
			elsif((dparam == nil || i >= dparam.length || dparam[i] == nil) && r.dest[i].respond_to?(:auto))
				r.dest[i].auto(*src)
			else
				mkRes(r.dest[i], spec, *dparam[i])
			end
		}

		libs = (options[:libs] || [])
		if(!libs.is_a?(Array)) then libs = [libs] end
		spec[:libraries] = (r.libs + libs).map { |lib|  lib.call(@buildMgr.settings, spec) }.uniq
		

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
		if(builders != nil)
			if(!builders.is_a?(Array)) then builders = [builders] end
			if(settings != nil && !settings.empty?)
				builders.each { |builder|
					@buildMgr.settings[MakeRb::SettingsKey[:builder => builder]]= settings
				}
			end
			if(r.settingsM != nil)
				builders.each { |builder|
					@buildMgr.settings.addSpecialized(r.settingsM, MakeRb::SettingsKey[:builder => builder])
				}
			end
		end
		dest
	end

	# Calls {#dep dep} on each element in the given array, using the given rule name.
	# @param [Array] params An array of arrays, each being passed to one call of {#dep dep}.
	# @return [Array] all the targets generated by {#dep dep}.
	def ddep(name, *params)
		params.flat_map { |param|
			dep(name, *param)
		}
	end

	# Loads all MEC files whose names start with any of the names passed as parameters.
	def loadExt(*names)
		names.each { |name|
			@buildMgr.mec.load(name)
		}
	end

	# Finds a {MakeRb::Resource Resource} by its name.
	def res(name)
		buildMgr[name] || raise("No resource called `#{name}' found")
	end

	# Callback/hook for creating resource instances
	def mkRes(klass, spec, *args)
		if(klass < FileRes)
			if(File.extname(args[0]).downcase == "")
				ext = @buildMgr.settings.getSettings(spec + MakeRb::SettingsKey[:resourceClass => klass])[:fileExt] || ""
				args[0] += ext
			end 
			klass.new(buildMgr, spec, (@tprefix||"")+args[0], *(args[1..-1]))
		else
			klass.new(buildMgr, spec, *args)
		end
	end

	# FileRes instances defined within the given block will get "dir" prefixed
	def subdir(dir,&block)
		if(!dir.is_a?(Pathname)) then dir = Pathname.new(dir) end
		old = @tprefix
		if(@tprefix != nil) then dir = @tprefix + dir end
		@tprefix = dir

		block.call

		@tprefix = old
	end
end
