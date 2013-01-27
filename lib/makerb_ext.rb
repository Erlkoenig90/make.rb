#!/usr/bin/env ruby

require 'pathname'
require 'set'

# MakeRb External Config (MEC)
module MakeRbExt
	# Manages loading MEC data from files
	class ExtManager
		attr_reader :dirpaths, :settings, :loaded
		# param [{MakeRb::SettingsMagrix}] settings_
		def initialize(settings_)
			@settings = settings_
			@loaded = []
			@modules = {}
			nativePaths = @settings.nativeSettings[:mecPaths].call()
			@dirpaths ||= ((ENV['MAKERB_EC_PATH'] || "").split(";").map{|p| Pathname.new(p) } +
				nativePaths).uniq
		end
		# Loads MEC files whose names begin with 'name'
		# @param [String] name
		def load(name)
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
				loadFile(file)
			}
		end
		# Loads the MEC file specified
		# @param [String] filename The name of the file to be loaded
		def loadFile(filename)
			descname = filename.basename.sub_ext("").to_s + "Desc"
			if(!@loaded.include?(descname))
				@loaded << descname

				filename = filename.to_s
				last = $mec_mgr

				$mec_mgr = self
				require(filename)
				$mec_mgr = last
				
				desc = begin
					MakeRbExt.const_get(descname)
				rescue NameError
					raise("File `#{filename}' should contain a ruby module `#{descname}', but doesn't")
				end
				
				desc.register(@settings)
			end
		end
		# Load all files which might contain the definition for the library with the given name
		# @param [String] MEC name in MEC library name format, e.g. GmoduleNoExport2
		# @return [Library] The loaded library of the given name
		def autoload(fname)
			lib = nil

			@dirpaths.each { |dp|
				if(dp.directory?)
					dp.opendir { |dir|
						dir.each { |f|
							if(f[0...name.length] == fname)
								loadFile(dp + fname)
								if(MakeRbExt.const_defined?(name))
									return MakeRbExt.const_get(name)
								end
							end
						}
					}
				end
			}
			raise("No library `#{name}' found")
		end
	end
	# A specific version of a {Library}. Create instances via {MakeRbExt.libver}
	class LibVersion
		attr_reader :parentSettings, :version, :name
		def initialize(ver, name_, parent = nil)
			@parentSettings = parent
			@version = ver
			@version.extend(Comparable)
			@name = name_
			
#			puts "Deps: " + deps.map{|l| l.name }.join(",")
		end
		def settingDeps(matrix, key)
			if ((deps = (matrix.getSettings({:mecLibrary => self})[:mecDependencies])) != nil)
				deps.call(matrix,key).map { |p| p.call(matrix,key) }
			else
				[]
			end
		end
	end
	# Returned by {Library#where}. A block which finds a version of a library when passed in a {MakeRb::SettingsMatrix}
	# and {MakeRb::SettingsKey specialisations}. Needed because usually, when calling {Library#where}, these two
	# aren't known yet.
	class LibProxyProc < Proc
	end
	# A library which has at least one version. Use {MakeRbExt::library} to create instances.
	class Library
		attr_reader :versions, :name, :description
		def initialize(name_, desc)
			@versions = {}
			@name = name_
			@description = desc
		end
		# Allows to use e.g. LibraryInstance >= [2,4,7], returns an appropriate {LibProxyProc}
		# @return [LibProxyProc]
		def method_missing(meth,*args)
			where { |ver|
				ver.respond_to?(meth) && ver.send(meth,*args)
			}
		end
		# Returns a block ({LibProxyProc}) which should get passed in a {MakeRb::SettingsMatrix} and a {MakeRb::SettingsKey}.
		# This block will return a version of this library which satisfies the condition(s) given via the 'block' parameter,
		# and also supports the given specialisation ({MakeRb::SettingsKey}). If no such library is found, it will throw an exception
		# @return [LibProxyProc]
		def where(&block)
			LibProxyProc.new { |matrix,key|
				if(set == nil)
					set = Set[]
				end
				srcloc = block.source_location
				srcloc = if(srcloc != nil) then srcloc[0] + ":" + srcloc[1].to_s else "<unknown>" end
				(@versions.select { |ver,lib|
					matrix.libSupports?(lib, key) && block.call(ver,lib)
				}.max(){ |a,b| a[0] <=> b[0] } || raise("No version of library `#{@name}' satisfying condition from #{srcloc} found: #{@versions}"))[1]
			}
		end
		# Returns a {LibProxyProc} which gives the newest library version 
		# @return [LibProxyProc]
		def latest
			where { |v| true } # where automatically gives the newest version
		end
	end
	
	# Defines a version of a {MakeRbExt.library defined} {Library}, if not already defined.
	# @param [Symbol] name The name of the library version, in CamelCase - will define a ruby constant MakeRb::name. e.g. GmoduleNoExport2_2_32_4
	# @param [Library] lib The corresponding {Library} instance
	# @param [Hash] options A hash with options:
	#   * :parent => An object to inherit settings from, see {MakeRb::SettingsMatrix} about inheriting settings
	def MakeRbExt.libver(name, lib, options={})
		if(!MakeRbExt.const_defined?(name))
			inst = LibVersion.new(options[:version] || [], name.to_s, options[:parent])
			MakeRbExt.const_set(name, inst)
			
			lib.versions[inst.version] = inst
		end
		MakeRbExt.const_get(name)
	end
	
	# Define a library. If there's already a library with this name, does nothing.
	# @param [Symbol] name the library name, in CamelCase notation - will define a ruby constant MakeRbExt::name. e.g. GmoduleNoExport2
	# @param [String] desc Optional textual library description
	# @return [Library] the created (or already existing) library
	def MakeRbExt.library(name, desc = "")
		if(!MakeRbExt.const_defined?(name))
			MakeRbExt.const_set(name, Library.new(name, desc))
		end
		MakeRbExt.const_get(name)
	end
	# Load MEC files starting with any of the given names
	# @param [Array] filename prefixes
	def MakeRbExt.loadExt(*names)
		names.each { |name|
			$mec_mgr.load(name)
		}
	end
	# For usage in MEC files - represents a reference to a library.
	class LibRef
		attr_accessor :name
		def initialize(n)
			@name = n
		end
		def ==(other)
			name == other.name
		end
	end
	# Represents a reference to a system (compiler, stdlib, OS) library. The name should be a simple string.
	class SysLibRef < LibRef
		def to_s
			"SysLibRef.new(" + name.inspect + ")"
		end
	end
	# Represents a reference to a library belonging to a MEC package (preferably the package which creates the instance). The name should
	# be a Pathname.
	class ShippedLibRef < LibRef
		def to_s
			"ShippedLibRef.new(Pathname.new(" + name.cleanpath.to_s.inspect + "))"
		end
	end
end
