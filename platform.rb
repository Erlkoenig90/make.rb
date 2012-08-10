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
	end
	def MakeRb.platforms
		@platforms ||= { "native" => Platform.native }
	end
end
