# Make.rb Library Configuration

require 'pathname'

module MakeRbLC
	class MLCManager
		attr_reader :dirpaths, :buildMgr
		def initialize(mgr)
			@buildMgr = mgr
			@dirpaths ||= (ENV['MAKERB_LC_PATH'] || "").split(";").map{|p| Pathname.new(p) } +
				[Pathname.new(Dir.home)+".mlc", if(MakeRb.isWindows)
					Pathname.new(ENV['ProgramFiles'], "mlc")
				else
					Pathname.new("/usr/lib/mlc")
				end ].uniq
			@packages = {}
		end
		def load(name)
			name.downcase!
			files = []
			@dirpaths.each { |dp|
				pd = dp + name
				if(pd.directory?)
					pd.opendir { |dir|
						dir.each { |f|
							if (f != "." && f != "..")
								files << pd + f
							end
						}
					}
				end
			}
			Package.new(name, self, files)
		end
		def [](str)
			if(@packages.include?(str))
				@packages[str]
			else
				pkg = load(str)
				@packages[str] = pkg
				pkg
			end
		end
	end
	class PkgDesc
		attr_reader :package
		def initialize(pkg)
			@package = pkg
		end
	end
	class Package < MakeRb::Library
		attr_reader :name, :mlcMgr, :classes, :instances, :settings # Hash: Platform => CommonSettings
		def initialize(name, mgr, files)
			@name = name
			@mlcMgr = mgr
			@settings = Hash.new { |hash, key|
				s = CommonSettings.new(Flags.new())
				hash[key] = s
				s
			}
			@classes = files.map { |f|
				require(f)
				
				className = Package.getClassname(f.basename.sub_ext("").to_s)
				begin
					MakeRbLC.const_get(className)
				rescue NameError
					nil
				end
			}.select{ |k| k != nil }
			@instances = @classes.map { |klass|
				if(klass < PkgDesc)
					puts "Loaded: " + klass.name
					klass.new(self)
				end
			}
		end
		def buildMgr
			@mlcMgr.buildMgr
		end
		def Package.getClassname(str)
			a = str.gsub(/[_-].?/) { |s| s[1].upcase }.gsub(/\W/, "")
			a[0].upcase + a[1..-1] 
		end
	end
end