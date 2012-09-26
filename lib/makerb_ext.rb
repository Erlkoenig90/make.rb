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

require 'pathname'
require 'set'

module MakeRbExt
	# MakeRb External Config (MEC)
	
	class ExtManager
		attr_reader :dirpaths, :buildMgr
		def initialize(mgr)
			@buildMgr = mgr
			@modules = {}
			@dirpaths ||= ((ENV['MAKERB_EC_PATH'] || "").split(";").map{|p| Pathname.new(p) } +
				if(MakeRb.isWindows)
					[Pathname.new(ENV['APPDATA']) + "mec", Pathname.new(ENV['ProgramFiles']) + "mec"]
				else
					[Pathname.new(Dir.home)+".mec", Pathname.new("/usr/lib/mec")]
				end).uniq
		end
		def load(name)
			name.downcase!
			files = []
			@dirpaths.each { |dp|
				if(dp.directory?)
					dp.opendir { |dir|
						dir.each { |f|
							if (f != "." && f != ".." && File.extname(f).downcase == ".rb" && f[0...name.length] == name)
								files << dp + f
							end
						}
					}
				end
			}
			files.each { |file|
				descname = ExtManager.getClassname(file.sub_ext("")) + "Desc"
				filename = file.to_s
				require(filename)
				
				desc = begin
					MakeRbExt.const_get(descname)
				rescue NameError
					raise("File `#{filename}' should contain a ruby class `#{descname}', but doesn't")
				end
				
				desc.register(@buildMgr.settings)
			}
		end
		def ExtManager.getClassname(fname)
			a = fname.basename.to_s.gsub(/[_-]\D/) { |s| s[1].upcase }.gsub(".", "_").gsub(/\W/, "")
			a[0].upcase + a[1..-1]
		end
	end
	
	class LibVersion
		attr_reader :parentSettings, :version, :deps, :name
		def initialize(ver, name_, parent = nil, deps_=nil)
			@parentSettings = parent
			@version = ver
			@version.extend(Comparable)
			@deps = deps_ || []
			@name = name_
			
#			puts "Deps: " + deps.map{|l| l.name }.join(",")
		end
	end
	class Library
		attr_reader :versions, :name
		def initialize(name_)
			@versions = {}
			@name = name_
		end
		def method_missing(meth,*args)
			where { |ver|
				ver.respond_to?(meth) && ver.send(meth,*args)
			}
		end
		def where(&block)
			Proc.new { |matrix,key,set=nil|
				if(set == nil)
					set = Set[]
				end
				srcloc = block.source_location
				srcloc = if(srcloc != nil) then srcloc[0] + ":" + srcloc[1].to_s else "<unknown>" end
				libver = (@versions.select { |ver,lib|
					matrix.libSupports?(lib, key) && block.call(ver)
				}.max(){ |a,b| a[0] <=> b[0] } || raise("No version of library `#{@name}' satisfying condition from #{srcloc} found: #{@versions}"))[1]
				
				if(!set.include?(libver))
					set << libver
					libver.deps.each { |dep|
						dep.call(matrix,key,set)
					}
				end
				set
			}
		end
		def latest
			where { |v| true }
		end
	end
	
	def MakeRbExt.libver(name, lib, options={})
		inst = LibVersion.new(options[:version] || [], name.to_s, options[:parent], options[:deps] || [])
		MakeRbExt.const_set(name, inst)
		
		lib.versions[inst.version] = inst
		lib
	end
	
	def MakeRbExt.library(name)
		if(!MakeRbExt.const_defined?(name))
			MakeRbExt.const_set(name, Library.new(name))
		end
		MakeRbExt.const_get(name)
	end
end
