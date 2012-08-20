#!/usr/bin/env ruby

module MakeRb
	class Platform
		attr_accessor :name, :cl_prefix, :settings
		def initialize(name, cl_prefix, s = nil)
			@name = name
			@cl_prefix = cl_prefix
			if(s == nil)
				@settings = CommonSettings.new
			else
				@settings = s
			end
		end
		def self.native()
			@@native ||= Platform.new("native", Hash.new(""))
		end
		def clone
			Platform.new(name, cl_prefix, settings.clone)
		end
		
		def Platform.get(str)
			if(MakeRb.platforms.include?(str))
				MakeRb.platforms[str].clone
			else
				s = str.split(':')
				if(s.size == 2)
					if(MakeRb.platforms.include?(s[0]))
						p = MakeRb.platforms[s[0]].clone
						p.cl_prefix = Hash.new(s[1])
						p
					else
						raise "Platform `#{str}' not found"
					end
				else
					raise "Platform `#{str}' not found"
				end
			end
		end
	end
	def MakeRb.platforms
		@platforms ||= {
			"native" => Platform.native,
			"stm32f4" => Platform.new("STM32F4", Hash.new(""), CommonSettings.new(
				CompilerSettings.new({MakeRbCCxx::GCC => BuilderSettings.new(Flags.new (
					["-mthumb", "-mcpu=cortex-m4", "-mfpu=fpv4-sp-d16", "-mfloat-abi=hard", "-DSTM32F4XX", "-ffunction-sections", "-fdata-sections", "-nostdlib"]))}),
				CompilerSettings.new({MakeRbCCxx::GCC => BuilderSettings.new(Flags.new (
					["-mthumb", "-mcpu=cortex-m4", "-mfpu=fpv4-sp-d16", "-mfloat-abi=hard", "-DSTM32F4XX", "-ffunction-sections", "-fdata-sections", "-nostdlib", "-fno-exceptions", "-fno-rtti"]))}),
				LinkerSettings.new({MakeRbCCxx::GCCLinker => BuilderSettings.new(Flags.new (
					["-mthumb", "-mcpu=cortex-m4", "-mfpu=fpv4-sp-d16", "-mfloat-abi=hard", "-static", "-Wl,-cref,-u,Reset_Handler", "-Wl,--gc-sections", "-Wl,--defsym=malloc_getpagesize_P=0x1000", "-nostdlib", "-ffunction-sections", "-fdata-sections"]))}),
					MakeRbCCxx::tc_gcc))
			}
	end
end
