#!/usr/bin/env ruby

module MakeRb
	class Platform
		attr_accessor :name, :cl_prefix, :cc_flags, :cxx_flags, :ld_flags
		def initialize(name, cl_prefix)
			@name = name
			@cl_prefix = cl_prefix
			@cc_flags = []
			@cxx_flags = []
			@ld_flags = []
		end
	end
end
