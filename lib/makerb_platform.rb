#!/usr/bin/env ruby

module MakeRb
	# A platform is any environment for running programs, which requires similar settings for building these programs.
	# This is usually a combination of processor architecture and operating system, e.g. linux-amd64, stm32f4 (with no OS)
	class Platform
		@@platforms = nil
		include Enumerable
		attr_reader :name, :settings, :regHash
		attr_accessor :parentSettings
		# @param [String] n The platform's (unique) name
		# @param [SettingsMatrix] s Settings specific for this platform
		# @param [MakeRbCCxx::Toolchain] tc the default toolchain for this platform
		# @param [Hash] rh A hash to save this platform in, used internally
		# @param [Proc] block This block will be called at the end of initialize and be passed this instance. Allows
		#   for more elegant definition of nested platforms
		def initialize(n, s = nil, p = nil, tc = nil, rh = nil, &block)
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
		# @return [MakeRbCCxx::ClToolchain] the default toolchain
		def defToolchain
			@defToolchain || (if(@parentSettings == nil) then nil else @parentSettings.defToolchain end)
		end
		# @return [Platform] The platform we are currently running on. This should be replaced to return an explicit
		#   platform
		def self.native()
			@@native ||= Platform.new("native", nil, nil, MakeRbCCxx.tc_gcc)
		end
		# Creates a new platform which has the current one as parent.
		# @param [String] n The platform's (unique) name
		# @param [SettingsMatrix] s Settings specific for this platform
		# @param [MakeRbCCxx::Toolchain] tc the default toolchain for this platform
		# @param [Proc] block This block will be called at the end of initialize and be passed this instance. Allows
		#   for more elegant definition of nested platforms
		# @return [Platform]
		def newChild(n, s = nil, tc = nil, &block)
			Platform.new(n, s, self, tc, regHash, &block)
		end
		# Returns a platform with the given name, or constructs one using the inline definitions in the name.
		def Platform.get(str)
			if(platforms.include?(str))
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

				Platform.new(str, set, parent, tc, @@platforms)
			end
		end
		# The hash of all platforms
		# @return [Hash]
		def Platform.platforms
			if(@@platforms != nil)
				@@platforms
			else
				@@platforms = {"native" => Platform.native}
				Platform.new("ARM", nil, nil, nil, @@platforms) { |pfArm|
					pfArm.newChild("stm32f4", SettingsMatrix.new(
						MakeRb::SettingsKey[:toolchain => MakeRbCCxx.tc_gcc, :language => MakeRbLang::C] =>
							MakeRb::Settings[:clFlags => ["-mthumb", "-mcpu=cortex-m4", "-mfpu=fpv4-sp-d16", "-mfloat-abi=hard", "-DSTM32F4XX", "-DARM_MATH_CM4", "-D__FPU_PRESENT=1", "-ffunction-sections", "-fdata-sections", "-nostdlib"]],
						MakeRb::SettingsKey[:toolchain => MakeRbCCxx.tc_gcc, :language => MakeRbLang::Cxx] =>
							MakeRb::Settings[:clFlags => ["-fno-exceptions", "-fno-rtti"]],
						MakeRb::SettingsKey[:toolchain => MakeRbCCxx.tc_gcc] =>
							MakeRb::Settings[:ldFlags => ["-mthumb", "-mcpu=cortex-m4", "-mfpu=fpv4-sp-d16", "-mfloat-abi=hard", "-static", "-Wl,-cref,-u,Reset_Handler", "-Wl,--gc-sections", "-Wl,--defsym=malloc_getpagesize_P=0x1000", "-ffunction-sections", "-fdata-sections"]]
					), MakeRbCCxx.tc_gcc)
				}
				@@platforms
			end
		end
	end
end
