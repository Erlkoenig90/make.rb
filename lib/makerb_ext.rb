#!/usr/bin/env ruby

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
		attr_reader :parentSettings, :version, :deps, :name, :privateDeps
		def initialize(ver, name_, parent = nil, deps_=nil, pdeps_ = nil)
			@parentSettings = parent
			@version = ver
			@version.extend(Comparable)
			@deps = deps_ || []
			@privateDeps = pdeps_ || []
			@name = name_
			
#			puts "Deps: " + deps.map{|l| l.name }.join(",")
		end
	end
	class LibProxyProc < Proc
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
			LibProxyProc.new { |matrix,key,set=nil|
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
					if(key[:staticLinking] || false)
						libver.privateDeps.each { |dep|
							dep.call(matrix,key,set)
						}
					end
				end
				set
			}
		end
		def latest
			where { |v| true }
		end
	end
	
	def MakeRbExt.libver(name, lib, options={})
		inst = LibVersion.new(options[:version] || [], name.to_s, options[:parent], options[:deps] || [], options[:pdeps] || [])
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
