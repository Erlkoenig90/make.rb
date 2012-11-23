#!/usr/bin/ruby

require './pkgconfig'

mecOutDir = Pathname.new("mec")
if(!mecOutDir.directory?)
	mecOutDir.mkdir
end
pcOutDir = Pathname.new("pc-check")
if(!pcOutDir.directory?)
	pcOutDir.mkdir
end



puts "== Loading .pc files == "
pkgs = Packages.loadPC
#puts "== Loading headers == "
#pkgs.each { |name,pkg| 
#	puts "Loading #{pkg.name} headers"
#	pkg.headers
#}
puts "== Scanning headers == "

regex = /^(\s*)(#)(\s*)(include)(\s*)(\S*)(\s*)$/
pkgs.each { |name,pkg|
	mod = false
	pkg.headers.each { |header|
#		puts header
		File.open(header) { |fd|
			fd.each_line { |line|
				m = begin
					regex.match(line)
				rescue
					nil
				end
				if (m != nil)
					incfile = m[6].strip
					if((incfile[0] == "<" && incfile[-1] == ">") || (incfile[0] == "\"" && incfile[-1] == "\""))
						incfile = incfile[1...-1]
					end
#					puts "incfile: " + incfile
					aincfile = nil
					own = pkg.includes.find { |depincdir|
						x = depincdir + incfile
						if(x.file? && pkg.headers.include?(x.to_s))
							aincfile = x
						end
					}
					if(own == nil)
						iDep = -1
						for i in 0...pkg.deps.length
							dep = pkg.deps[i]
							if(dep[0].includes.find { |depincdir|
								x = depincdir + incfile
								if(x.file? && dep[0].headers.include?(x.to_s))
									aincfile = x
									true
								else
									false
								end
							})
								iDep = i
								break
							end
						end
						iDepP = -1
						for i in 0...pkg.depsP.length
							dep = pkg.depsP[i]
							if(dep[0].includes.find { |depincdir|
								x = depincdir + incfile
								if(x.file? && dep[0].headers.include?(x.to_s))
									aincfile = x
									true
								else
									false
								end
							})
								iDepP = i
								break
							end
						end
						if(iDep == -1 && iDepP != -1)
							puts "Problem found: Header #{header} of Package #{name} depends on #{aincfile}, provided by the private dependency #{pkg.depsP[iDepP][0].name}"
							mod = true
							pkg.deps << pkg.depsP[iDepP]
							pkg.depsP.delete_at(i)
						end
					end
				end
			}
		}
	}
	pkg.toMEC(mecOutDir + (name + ".rb"))
	if(mod)
		puts "Generating new #{pkg.pcfile.basename}"
		File.open(pkg.pcfile) { |ifd|
			File.open(pcOutDir + pkg.pcfile.basename.to_s, "w") { |ofd|
				ifd.each_line { |line|
					if(m = /^(Requires\:)(\s*)(.*)(\s*)$/.match(line))
					elsif(m = /^(Requires.private\:)(\s*)(.*)(\s*)$/.match(line))
					else
						ofd.write(line)
					end
				}
				ofd.write("Requires:")
				pkg.deps.each { |dep|
					ofd.write(" " + dep[0].name)
					if(dep.size == 3)
						ofd.write(" " + dep[1] + " " + dep[2])
					end
				}
				ofd.puts
				ofd.write("Requires.private:")
				pkg.depsP.each { |dep|
					ofd.write(" " + dep[0].name)
					if(dep.size == 3)
						ofd.write(" " + dep[1] + " " + dep[2])
					end
				}
				ofd.puts
			}
		}
	end
}

