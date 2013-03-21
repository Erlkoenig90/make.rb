#!/usr/bin/env ruby

module MakeRb
	# A platform is any environment for running programs, which requires similar settings for building these programs.
	# This is usually a combination of processor architecture and operating system, e.g. linux-amd64, stm32f4 (with no OS)
	class Platform
		@@platforms = nil
		include Enumerable
		attr_reader :name, :settings, :regHash, :regex
		attr_accessor :parentSettings
		# @param [String] n The platform's (unique) name
		# @param [SettingsMatrix] s Settings specific for this platform
		# @param [Platform] p Parent platform
		# @param [MakeRbCCxx::Toolchain] tc the default toolchain for this platform
		# @param [Regexp] regex A regular expression that should match on RUBY_PLATFORM if, and only if, we are currently
		#	running on that platform (or nil if make.rb can't run on that platform)
		# @param [Hash] rh A hash to save this platform in, used internally
		# @param [Proc] block This block will be called at the end of initialize and be passed this instance. Allows
		#   for more elegant definition of nested platforms
		def initialize(n, s = nil, p = nil, tc = nil, regex = nil, rh = nil, &block)
			@name = n
			@parentSettings = p
			@settings = s || SettingsMatrix.new({})
			@settings.hash.each { |key,val|
				if(!key.include?(:platform))
					key[:platform] = self
				end
			}
			@settings.hash.rehash
			@defToolchain = tc
			@regex = regex
			
			@regHash = rh
			if(rh != nil)
				rh[n] = self
			end
			if(block != nil)
				block.call(self)
			end
		end
		def to_s
			object_id.to_s + "#" + @name # + ":" + parentSettings.name
		end
		# Checks whether we are currently running on this platform
		# @return [Boolean]
		def running?
			(@regex != nil && (@regex =~ RUBY_PLATFORM) != nil) 
		end
		# @return [MakeRbCCxx::ClToolchain] the default toolchain
		def defToolchain
			@defToolchain || (if(@parentSettings == nil) then nil else @parentSettings.defToolchain end)
		end
		# @return [Platform] The platform we are currently running on.
		def self.native()
			@@native ||= (platforms.find {|key,pf| pf.running? }[1] ||
				raise("Could not determine the current platform. This is a missing feature in make.rb. Please fix or report"))
		end
		# Creates a new platform which has the current one as parent.
		# @param [String] n The platform's (unique) name
		# @param [SettingsMatrix] s Settings specific for this platform
		# @param [MakeRbCCxx::Toolchain] tc the default toolchain for this platform
		# @param [Regexp] regex A regular expression that should match on RUBY_PLATFORM if, and only if, we are currently
		#	running on the new platform (or nil if make.rb can't run on that platform)
		# @param [Proc] block This block will be called at the end of initialize and be passed this instance. Allows
		#   for more elegant definition of nested platforms
		# @return [Platform]
		def newChild(n, s = nil, tc = nil, regex = nil, &block)
			Platform.new(n, s, self, tc, regex, regHash, &block)
		end
		# Returns a platform with the given name, or constructs one using the inline definitions in the name.
		def Platform.get(str)
			if(platforms.include?(str) || str=="native")
				platforms[str]
			else
				# Parse specification string
				idx = str.index(",")
				pfName = if(idx == nil) then str else str[0...idx] end 
				parent = platforms[pfName] || (raise "Platform `#{pfName}' not found")
				
				hash = {}
				while(idx != nil)
					idx2 = str.index(":", idx+1) || (raise "Error in platform specification string - expected `:' after `,'")
					key = str[idx+1...idx2]
					
					# TODO - better parsing here.
					idx = str.index(",", idx2+2)
					value = if(idx == nil) then str[idx2+1..-1] else str[idx2+1...idx] end
					hash[key] = value
				end
				
				# Construct new platform
				tc = if(hash.include?("tc"))
					tcname = hash["tc"];
					MakeRbCCxx.toolchains[tcname] || raise("Toolchain`#{tcname}' not found")
				else
					nil
				end
				set = SettingsMatrix.new()
				if(hash.include?("cFlags"))
					# TODO Better parsing here
					set.hash[{:language => MakeRbLang::C}] = Settings[:clFlags => hash["cFlags"].split(" ")]
				end
				if(hash.include?("cxxFlags"))
					# TODO Better parsing here
					set.hash[{:language => MakeRbLang::Cxx}] = Settings[:clFlags => hash["cxxFlags"].split(" ")]
				end
				if(hash.include?("ldFlags"))
					# TODO Better parsing here
					set.hash[{}] = Settings[:ldFlags => hash["ldFlags"].split(" ")]
				end
				if(hash.include?("prefix"))
					set.hash[if(tc == nil) then {} else {:toolchain => tc} end] = Settings[:clPrefix => hash["prefix"]]
				end

				Platform.new(str, set, parent, tc, nil, @@platforms)
			end
		end
		# The hash of all platforms
		# @return [Hash]
		def Platform.platforms
			if(@@platforms != nil)
				@@platforms
			else
				@@platforms = Hash.new {|name|
					if(name == "native") then @@platforms["native"] = Platform.native
					else nil end
				}
				Platform.new("ARMv7M", SettingsMatrix[
					{:toolchain => MakeRbCCxx.tc_gcc, :language => MakeRbLang::C} => {:clFlags => ["-mthumb"]},
					{:toolchain => MakeRbCCxx.tc_gcc} => {:ldFlags => ["-mthumb"], :startupCode => Pathname.new(File::expand_path("../../data/startup/gcc/ARMv7M.c", __FILE__))},
					{:toolchain => MakeRbCCxx.tc_gcc, :resourceClass => MakeRbBinary::StaticLibrary} =>
						{ :fileExt => ".a" },
					{:toolchain => MakeRbCCxx.tc_gcc, :resourceClass => MakeRbBinary::DynLibrary} =>
						{ :fileExt => ".so" },
					{:toolchain => MakeRbCCxx.tc_gcc, :resourceClass => MakeRbBinary::Executable} =>
						{ :fileExt => ".elf" }], nil, MakeRbCCxx.tc_gcc, nil, @@platforms) { |pfArm|
					
						pfArm.newChild("Cortex-M4F", SettingsMatrix[
							{:toolchain => MakeRbCCxx.tc_gcc, :language => MakeRbLang::C} =>
							{:clFlags => ["-mcpu=cortex-m4", "-mfpu=fpv4-sp-d16", "-mfloat-abi=hard"],
							 :ldFlags => ["-mcpu=cortex-m4", "-mfpu=fpv4-sp-d16", "-mfloat-abi=hard"]
							}]) { |m4f|
							
							mcus = ["STM32F302CB", "STM32F302CC", "STM32F302RB", "STM32F302RC", "STM32F302VB", "STM32F302VC", "STM32F303CB", "STM32F303CC", "STM32F303RB", "STM32F303RC", "STM32F303VB", "STM32F303VC", "STM32F313CC", "STM32F313RC", "STM32F313VC", "STM32F372C8", "STM32F372CB", "STM32F372CC", "STM32F372R8", "STM32F372RB", "STM32F372RC", "STM32F372V8", "STM32F372VB", "STM32F372VC", "STM32F373C8", "STM32F373CB", "STM32F373CC", "STM32F373R8", "STM32F373RB", "STM32F373RC", "STM32F373V8", "STM32F373VB", "STM32F373VC", "STM32F383CC", "STM32F383RC", "STM32F383VC", "STM32F405OE", "STM32F405OG", "STM32F405RG", "STM32F405VG", "STM32F405ZG", "STM32F407IE", "STM32F407IG", "STM32F407VE", "STM32F407VG", "STM32F407ZE", "STM32F407ZG", "STM32F415OG", "STM32F415RG", "STM32F415VG", "STM32F415ZG", "STM32F417IE", "STM32F417IG", "STM32F417VE", "STM32F417VG", "STM32F417ZE", "STM32F417ZG", "STM32F427IG", "STM32F427II", "STM32F427VG", "STM32F427VI", "STM32F427ZG", "STM32F427ZI", "STM32F429BG", "STM32F429BI", "STM32F429IG", "STM32F429II", "STM32F429NG", "STM32F429NI", "STM32F429VG", "STM32F429VI", "STM32F429ZG", "STM32F429ZI", "STM32F437IG", "STM32F437II", "STM32F437VG", "STM32F437VI", "STM32F437ZG", "STM32F437ZI", "STM32F439BG", "STM32F439BI", "STM32F439IG", "STM32F439II", "STM32F439NG", "STM32F439NI", "STM32F439VG", "STM32F439VI", "STM32F439ZG", "STM32F439ZI"]
							mcus.each { |n|
								b = {{} => {:cppDefines => {n => "1", n[0..-3] => "1"}}}
								MakeRbCCxx.toolchains.each { |tcname,tc|
									ext = (MakeRbLang.settings.getSettings(MakeRb::SettingsKey[:toolchain => tc, :resourceClass => MakeRbBinary::LinkerScript])[:fileExt]) || ""
									lp = Pathname.new(File::expand_path("../../data/linkerscript/#{tcname}/#{n}#{ext}", __FILE__))
									if(lp.file?)
#										puts "found linkerscript #{lp.to_s}"
										b[{:toolchain => tc}] = {:linkerScript => lp}
									end
									m4f.newChild(n, MakeRb::SettingsMatrix[b])
								}
							}
						}
				}
				Platform.new("linux-x86", SettingsMatrix.new(
					MakeRb::SettingsKey[:staticLinking => true] =>
						MakeRb::Settings[ :libRefNaming => [ /^(\.a)$/, /^(\.o)$/ ]],
					MakeRb::SettingsKey[:staticLinking => false] =>
						MakeRb::Settings[ :libRefNaming => /^(\.so)$/ ],
					MakeRb::SettingsKey[:toolchain => MakeRbCCxx.tc_gcc, :resourceClass => MakeRbBinary::StaticLibrary] =>
						MakeRb::Settings[ :fileExt => ".a" ],
					MakeRb::SettingsKey[:toolchain => MakeRbCCxx.tc_gcc, :resourceClass => MakeRbBinary::DynLibrary] =>
						MakeRb::Settings[ :fileExt => ".so" ],
					MakeRb::SettingsKey[:toolchain => MakeRbCCxx.tc_gcc, :resourceClass => MakeRbBinary::Executable] =>
						MakeRb::Settings[ :fileExt => "" ],
					MakeRb::SettingsKey[] => MakeRb::Settings[ :nullFile => "/dev/null", :mecPaths => Proc.new { [Pathname.new(Dir.home)+".mec", Pathname.new("/usr/lib/mec")] } ]
				), nil, MakeRbCCxx.tc_gcc, /x86_linux/, @@platforms) { |pfLinux|
					pfLinux.newChild("linux-x86_64", nil, nil, /x86_64-linux/)
				}

				Platform.new("windows-x86", SettingsMatrix.new(
					MakeRb::SettingsKey[:staticLinking => true] =>
						MakeRb::Settings[ :libRefNaming => [ /^(?<!\.dll)(\.a)$/, /^(\.o)$/, /^(\.lib)$/, /^(\.dll\.a)$/, /^(\.dll)$/ ] ],
					MakeRb::SettingsKey[:staticLinking => false] =>
						MakeRb::Settings[ :libRefNaming => [ /^(\.dll)$/, /^(\.dll\.a)$/, /^(\.a)$/, /^(\.lib)$/, /^(\.o)$/ ] ],
					MakeRb::SettingsKey[:toolchain => MakeRbCCxx.tc_gcc, :resourceClass => MakeRbBinary::StaticLibrary] =>
						MakeRb::Settings[ :fileExt => ".a" ],
					MakeRb::SettingsKey[:toolchain => MakeRbCCxx.tc_gcc, :resourceClass => MakeRbBinary::DynLibrary] =>
						MakeRb::Settings[ :fileExt => ".dll" ],
					MakeRb::SettingsKey[:toolchain => MakeRbCCxx.tc_gcc, :resourceClass => MakeRbBinary::Executable] =>
						MakeRb::Settings[ :fileExt => ".exe" ],
					MakeRb::SettingsKey[] => MakeRb::Settings[ :nullFile => "NUL", :mecPaths => lambda { [Pathname.new(ENV['APPDATA']) + "mec", Pathname.new(ENV['SystemDrive'] + "\\mec")] } ]
				), nil, MakeRbCCxx.tc_gcc, /cygwin|mswin|mingw|bccwin|wince|emx/, @@platforms)
				@@platforms["native"] = Platform.native
				@@platforms
			end
		end
	end
end
