# Make.rb Library Configuration

require 'pathname'

module MakeRbLC
	class MLCManager
		attr_reader :dirpaths
		def initialize
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
			Package.new(name, files)
		end
		def [](str)
			if(@packages.include?(str))
				@packages[str]
			else
				p = load(str)
				@packages[str] = p
				p
			end
		end
	end
	class Package
		attr_reader :classes
		def initialize(name, files)
			@classes = files.map { |f|
				require(f)
				
				className = Package.getClassname(f.basename.sub_ext("").to_s)
				begin
					MakeRbLC.const_get(className)
				rescue NameError
					nil
				end
			}.select{ |k| k != nil }
		end
		def Package.getClassname(str)
			a = str.gsub(/[_-].?/) { |s| s[1].upcase }.gsub(/\W/, "")
			a[0].upcase + a[1..-1] 
		end
	end
end