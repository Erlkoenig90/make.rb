#!/usr/bin/ruby

require 'pathname'
require 'make.rb'
require 'set'

$pkg_root = Pathname.new("c:/dev/MinGW/msys/1.0/home/erlkoenig")
$blacklist = [] #  ["avahi-qt3.pc"] #, "gnutls-dane.pc", "cogl-pango-2.0-experimental.pc"]
# $library_path = [Pathname.new("/usr/lib"), Pathname.new("/lib")] + ((ENV["LD_LIBRARY_PATH"] || "").split(":").map{|f| Pathname.new(f)})
$sys_libpaths = [Pathname.new(ENV['WINDIR']), Pathname.new(ENV['WINDIR'] + "/System32")]
$sys_libpaths2 = [Pathname.new("C:\\dev\\MinGW\\lib")]
# $preload = ["expat", "libiconv", "gettext", "zlib", "freetype"]

$dynLibExts = [/^(\.dll\.a|\.lib)$/, /^\.dll$/, /^\.a$/, /^\.o$/]
$pLibExts = [/^(?<!\.dll)\.a$/, /^\.o$/, /^(\.dll\.a|\.lib)$/, /^\.dll$/]
#


class LShippedLibRef
	attr_accessor :name, :lname # Legacy name, like -lfoo
	def initialize(n, ln)
		@lname = if(ln[0..2] == "lib")
			"-l" + ln[3..-1]
		else
			ln
		end
		@name = n
	end
	def ==(other)
		name == other.name
	end
	def to_s
		"ShippedLibRef.new(Pathname.new(" + name.cleanpath.to_s.inspect + "))"
	end
end


class LSysLibRef
	attr_accessor :name, :lname # Legacy name, like -lfoo
	def initialize(n, ln)
		@lname = if(ln[0..2] == "lib")
			"-l" + ln[3..-1]
		else
			ln
		end
		@name = n
	end
	def ==(other)
		name == other.name
	end
	def to_s
		"SysLibRef.new(" + name.inspect + ")"
	end
end

def translatePkgName(pkg)
	a = pkg.gsub(/[_-]\D/) { |s| s[1].upcase }.gsub(/[_-]\d/) { |s| "_" + s[1] }.gsub(".", "_").gsub(/\W/, "")
	a[0].upcase + a[1..-1]
end

def getPkgFiles(file)
	pkg = `pacman -Qqo #{file}`
	`pacman -Qql #{pkg}`.split("\n").map{|f| f.strip }.select { |f| File.file?(f) }
end

def filesR(root,subpath=Pathname.new(""),&block)
	apath = root+subpath
	apath.opendir { |od|
		od.each { |ff|
			if(ff != "." && ff != "..")
				fp = subpath + ff
				afpath = (root + fp).realpath.cleanpath
				if(afpath.directory?)
					filesR(root,fp,&block)
				else
					block.call(fp,ff,afpath)
				end
			end
		}
	}
end


class SysLibrary < Pathname
end

class StdLibrary < Pathname
end

class ShippedLibrary < Pathname
end

class Packages < Hash
	def self.loadPC(root = $pkg_root, blacklist = $blacklist, preload = $preload)
		cachepath = root + "pc-cache.bin"
		if(cachepath.file?)
			File.open(cachepath) { |cf|
				Marshal.load(cf)
			}
		else
			puts "Loading Packages from #{root}"
			pkgs = self.new()
			root.opendir { |d|
				d.each { |pd|
					if(m = /^(.*)(_install)$/.match(pd))
						pkgroot = root+pd
						filesR(pkgroot) { |fp,ff,afpath|
							if(m2 = /^(.*)(\.pc)$/.match(ff))
								pkg = Package.fromPC(pkgs,afpath,pkgroot)
								pkgs[pkg.name] = pkg
							end
						}
					end
				}
			}
			puts "Iteratively resolving dependencies"
			cont = true
			while(cont)
				cont = false
				pkgs.each { |name,pkg|
					cont ||= pkg.resolveDeps(pkgs)
				}
			end
			puts "Resolving leftover dependencies to syslibs"
			pkgs.each { |name, pkg|
				pkg.resolveLastDeps(pkgs)
			}
			File.open(cachepath, "w") { |cf|
				Marshal.dump(pkgs, cf)
			}
			pkgs
		end
	end
	def getDep (pkgname, operator=nil, version=nil)
		f = fetch(pkgname, nil) || raise("Dependency `#{pkgname}' not found")
		
		if((operator == nil) || (operator == "=" && f.version == version) || (operator == ">" && f.version > version) || (operator == ">=" && f.version >= version) || (operator == "<" && f.version < version) || (operator == "<=" && f.version <= version))
			f
		else
			raise "Package #{pkgname} doesn't satisfy condition #{operator} #{version}"
		end
	end
end

class Version < Array
	include Comparable
	def to_s
		join(".")
	end
end

class Package
	attr_accessor :name, :includes, :version, :deps, :depsP, :pcfile, :libraries, :librariesP, :unresolvedLibs, :unresolvedLibsP, :ldflags, :ldflagsP, :cflags, :description, :pkgroot
	def initialize(s, name_, ver, pcfile_, deps_, depsP_, libs, libsP, unresolvedLibs_, unresolvedLibsP_, ldflags_, ldflagsP_, cflags_, inc, desc, pkgroot_)
#		puts "Package (#{name_}, #{ver})"
		@packages = s
		@name = name_
		@version = ver
		@includes = inc
		@pcfile = pcfile_
		@deps = deps_
		@depsP = depsP_
		@libraries = libs
		@librariesP = libsP
		@cflags = cflags_
		@ldflags = ldflags_
		@ldflagsP = ldflagsP_
		@description = desc
		@unresolvedLibs = unresolvedLibs_
		@unresolvedLibsP = unresolvedLibsP_
		@pkgroot = pkgroot_
	end
	def self.pkg_cconf(str, vars, prefix)
		#	p vars
		str.gsub("@PREFIX@", prefix.to_s).gsub(/(\$\{)([^\}]*)(\})/) { |name|
			name = name[2 .. -2]
			#		puts "#{name} ---> #{vars[name]}"
			vars[name]
		}
		#	str.gsub(/(\$\{)/) { |name| vars[name] }
	end
	def self.decodeVersion(str)
		Version.new(str.split(".").map { |x| x.to_i })
	end
	def self.decodeLDFlags(flags)
		dirs = []
		files = []
		flags.delete_if { |flag|
			if(flag[0..1] == "-L")
				dirs << Pathname.new(flag[2..-1])
				true
			elsif(flag[0..1] == "-l")
				files << "lib" + flag[2..-1]
				true
			else
				false
			end
		}
		[dirs, files]
	end
	def self.findInclude(name, pc)
		if(name.directory?)
			name
		else
			(x = [Pathname.new(pc.dirname.parent.parent.to_s + "/" + name.to_s), pc.dirname.parent.parent + name]).each { |i|
				begin
					i = i.realpath.cleanpath
					if(i.directory?)
						return i
					end
				rescue
				end
			}
			raise("#{pc}: Include path `#{name}' not found")
		end
	end
	def self.findLibfiles(pkgname, exts, files, pkgroot, appendDeps, pkgs, unresolved)
		before = files.length
		files.uniq!
		if(files.length != before)
			puts "Warning: Library file list of #{pkgname} contains doubles"
		end
#		puts "findLibfiles(#{exts}, #{dirs}, #{files})"
		found = []
		files.each { |f|
			file = nil
#			puts "dirs: " + dirs.inspect
			# Search for library file in specified libdirs
			filesR(pkgroot) { |fp,ff,afpath|
				exts.each { |ext|
					if(ff[0...f.length] == f && ff[f.length..-1] =~ ext)
						puts "Associating shipped lib #{f} => #{fp}"
						file = fp
						found << LShippedLibRef.new(fp, f)
#						puts "Found #{file}"
						break
					end
				}
				if(file != nil) then break end
			}
			# Search for library file in external (system) paths
			if(file == nil)
				$sys_libpaths.each { |d2|
					d2.opendir { |dir|
						dir.each { |ff|
							exts.each { |ext|
#								if(ff == "ws2_32.dll") then raise "foo #{f[0..2]}" end
								if(ff[0...f.length] == f && ff[f.length..-1] =~ ext)
									file = (d2 + ff).realpath.cleanpath
									found << LSysLibRef.new(f, f)
									puts "Associating syslib #{f} to #{file}"
									break
								elsif(f[0..2] == "lib" && ff[0...f.length-3] == f[3..-1] && ff[f.length-3..-1] =~ ext)
									file = (d2 + ff).realpath.cleanpath
									found << LSysLibRef.new(ff[0...f.length-3], f)
									puts "Associating syslib #{f} to #{file}"
									break
								end
							}
							if(file != nil) then break end
						}
					}
					if(file != nil) then break end
				}
			end

			if(file == nil)
				unresolved << f
			end
		}
		found
	end
	def self.fromPC(pkgs, path, pkgroot)
		pkgname = path.basename.sub_ext("").to_s
		puts "loading #{pkgname}"
		
		version = nil
		cflags = []
		ldflags = []
		ldflagsP = []
		desc = ""
		deps = []
		depsPrivate = []
		vars = {}
		pathx = path.sub_ext(".pc.bak")
		if(!pathx.file?) then pathx = path end
		
		File.open(pathx) { |f|
			f.each { |line|
				if(m = /^(Cflags\:)(\s*)(.*)(\s*)$/.match(line))
					#					p m
					cflags = MakeRb.parseFlags(pkg_cconf(m[3], vars, pkgroot))
				elsif(m = /^(Description\:)(\s*)(.*)(\s*)$/.match(line))
					desc = pkg_cconf(m[3], vars, pkgroot)
				elsif(m = /^(Libs\:)(\s*)(.*)(\s*)$/.match(line))
					ldflags = MakeRb.parseFlags(pkg_cconf(m[3], vars, pkgroot))
				elsif(m = /^(Version\:)(\s*)(.*)(\s*)$/.match(line))
					version = decodeVersion(pkg_cconf(m[3], vars, pkgroot))
				elsif(m = /^(Libs.private\:)(\s*)(.*)(\s*)$/.match(line))
					ldflagsP = MakeRb.parseFlags(pkg_cconf(m[3], vars, pkgroot))
				elsif((m1 = /^(Requires\:)(\s*)(.*)(\s*)$/.match(line)) || (m2 = /^(Requires.private\:)(\s*)(.*)(\s*)$/.match(line)))
					depsProxy = if(/^(Requires\:)(\s*)(.*)(\s*)$/.match(line))
						m = m1
						deps
					else
						m = m2
						depsPrivate
					end
					#					p m
					str = pkg_cconf(m[3], vars, pkgroot).strip
#					p str
					#					p str
					l = 0
					mode = 0
					words = []
					for i in 0...str.length
						c = str[i]
						if(mode == 0)
							if(" \t,".include?(c))
							else
								l = i
								if("<>=".include?(c))
									mode = 2
								else
									mode = 1
								end
							end
						elsif(mode == 1)
							if("<>=".include?(c))
								mode = 2
								words << str[l...i]
								l = i
							elsif(" \t,".include?(c))
								mode = 0
								words << str[l...i]
								l = i
							end
						else
							if(" \t,".include?(c))
								mode = 0
								words << str[l...i]
								l = i
							end
						end
					end
#					p "#{pkgname} remains: #{str[l..-1]}"
					if(str.length > 0) then words << str[l..-1] end

					#					p words
					i = 0
					while(i < words.length)
						k = i
						if(i+2 < words.length && [">=","<=","<",">","="].include?(words[i+1]))
#							puts "#{pkgname} requiring in #{words[i]}"
							if (words[i] != "pkg-config")
								depsProxy << [words[i], words[i+1], decodeVersion(words[i+2])]
							end
							i = i + 3
						else
#							puts "#{pkgname} requiring in #{words[i]}"
							if (words[i] != "pkg-config")
								depsProxy << [words[i]]
							end
							i = i + 1
						end
					end
				elsif(m = /^([^=]*)=(.*)$/.match(line))
					vars[m[1]] = pkg_cconf(m[2], vars, pkgroot)
				end
			}
		}
		includes = []
		cflags.delete_if { |flag|
			if(flag[0..1] == "-I")
				includes << findInclude(Pathname.new(flag[2..-1]), path)
				true
			else
				false
			end
		}
		ldflags_d = decodeLDFlags(ldflags)
		ldflagsP_d = decodeLDFlags(ldflagsP)
		ldflagsP_d[0].concat(ldflags_d[0])
#		puts pkgname
#		puts "X:" + ldflags_d.inspect
#		puts "Y:" + ldflagsP_d.inspect
		unres = []
		unresP = []
#		begin
			libs = findLibfiles(pkgname, $dynLibExts, ldflags_d[1], pkgroot, deps, pkgs, unres)
			libsP = findLibfiles(pkgname, $pLibExts, ldflagsP_d[1], pkgroot, depsPrivate, pkgs, unresP)
#		rescue
#			raise pkgname + ": " + $!.to_s
#		end
		
		if(version == nil)
			raise "No version for package #{pkgname} (#{path}) given"
		end
		Package.new(pkgs, pkgname, version, path, deps, depsPrivate, libs, libsP, unres, unresP, ldflags, ldflagsP, cflags, includes, desc, pkgroot)
	end
	def resolveDepsX(pkgs,deps,unresolved,exts)
		deps.map! { |d|
			if(d.is_a?(Array) && d[0].is_a?(String))
#				puts "getDep(#{d.inspect})"
				[pkgs.getDep(*d)] + d[1..-1]
			else
				d
			end
		}
		mod = false
		# Search for library file in other Packages
		unresolved.delete_if { |f|
			found = false
			pkgs.each { |pkgname, pkg|
				pkg.libraries.each { |flib|
					if(flib.is_a?(LShippedLibRef))
						if(flib.lname == f)
							puts "Warning: #{name}: Substituting specified #{f} with dependency to package #{pkg.name} (#{flib.name.to_s}) via lname #{flib.lname}"
							deps << [pkg]
							found = true
							mod = true
							break
						else
							ff = flib.name.basename.to_s
							exts.each { |ext|
								if((f[0..2] == "lib" && ff[0...f.length-3] == f[3..-1] && ff[f.length-3..-1] =~ ext) ||
									(ff[0...f.length] == f && ff[f.length..-1] =~ ext))
									puts "Warning: #{name}: Substituting specified #{f} with dependency to package #{pkg.name} (#{flib.name.to_s})"
									deps << [pkg]
									found = true
									mod = true
									break
								end
							}
						end
					end
				}
				if(found) then break end
			}
			found
		}
		mod
	end
	def resolveDeps(pkgs)
		resolveDepsX(pkgs, @deps, @unresolvedLibs, $dynLibExts) |
			resolveDepsX(pkgs, @depsP, @unresolvedLibsP, $pLibExts)
	end
	def resolveLastDepsX(pkgs,deps,unresolved,libs,exts)
		unresolved.each { |f|
			found = false
			$sys_libpaths2.each { |d2|
				d2.opendir { |dir|
					dir.each { |ff|
						exts.each { |ext|
	#						if(ff == "ws2_32.dll") then raise "foo #{f[0..2]}" end
							if(ff[0...f.length] == f && ff[f.length..-1] =~ ext)
								file = (d2 + ff).realpath.cleanpath
								libs << LSysLibRef.new(f, f)
								puts "Associating syslib #{f} to #{file}"
								found = true
								break
							elsif(f[0..2] == "lib" && ff[0...f.length-3] == f[3..-1] && ff[f.length-3..-1] =~ ext)
								file = (d2 + ff).realpath.cleanpath
								libs << LSysLibRef.new(ff[0...f.length-3], f)
								puts "Associating syslib #{f} to #{file}"
								found = true
								break
							end
						}
						if(found) then break end
					}
				}
				if(found) then break end
			}
			if(!found)
				raise "Couldn't find dependency #{f} of package #{name}"
			end
		}
	end
	def resolveLastDeps(pkgs)
		resolveLastDepsX(pkgs, @deps, @unresolvedLibs, @libraries, $dynLibExts) |
			resolveLastDepsX(pkgs, @depsP, @unresolvedLibsP, @librariesP, $pLibExts)
	end
	def headers
		@headers ||= getPkgFiles(@pcfile).select { |str|
			@includes.inject(false) { |mem,obj|
				s = obj.to_s
#				puts "Comparing #{str[0...s.length]} <=> #{s}"
				mem || str[0...s.length] == s
			}
		}
	end
	def toMEC(outdir)
		mecname = translatePkgName(name)
		mecpath = outdir + (mecname + ".rb")
		mecpath.open("w") { |mecfile|
			pkg = self
			mecfile.puts "module MakeRbExt"
			
			mecver = mecname + "_" + pkg.version.join("_")
			deps = [pkg.deps,pkg.depsP].map { |d|
				d.map { |dep|
					op = if(dep[1] == "=") then "==" else dep[1] end;
					translatePkgName(dep[0].name) + (if(dep.size == 1) then ".latest" else " " + op + " " + dep[2].inspect end)
				}
			}  
			
			mecfile.puts "\t# file: " + pkg.pcfile.to_s
			
			mecfile.puts "\tlibrary :#{mecname}, #{@description.inspect}\n"
			mecfile.puts("\tlibver :#{mecver}, #{mecname}, version:" + pkg.version.inspect)
			
			mecDep = ((pkg.deps + pkg.depsP).map { |d| translatePkgName(d[0].name).inspect }) +
				if((pkg.librariesP+pkg.libraries).inject(false) { |mem,obj| mem || obj.is_a?(LSysLibRef) }) then ["\"SysLibs\""] else [] end
			if(pkg.deps.size + pkg.depsP.size > 0) then mecfile.puts "\tloadExt " + mecDep.uniq.join(",") end
	
			mecfile.puts "\tmodule #{mecname}Desc\n\t\tdef #{mecname}Desc.register(settings)"
#			mecfile.puts "\t\t\tprefix = Pathname.new(\"@@PREFIX@@\");"
#			mecfile.puts "\t\t\tprefix = Pathname.new(" + pkg.pkgroot.to_s.inspect + ");"
			mecfile.puts "\t\t\tprefix = Pathname.new(\"C:\\\\Posix\")"
			
			mecfile.write "\t\t\tkey = MakeRb::SettingsKey[:libraries => #{mecver}, :platform => MakeRb::Platform.platforms[" + MakeRb::Platform.native.name.inspect + "], :toolchain => MakeRbCCxx.tc_gcc, :language => MakeRbLang::C]\n"
			mecfile.write "\t\t\tsettings[key] =
		\t\t\tMakeRb::Settings[:support => true"
			if(!pkg.cflags.empty?) then mecfile.write ", :clFlags => #{pkg.cflags.inspect}" end
			if(!pkg.ldflags.empty?) then mecfile.write ", :ldFlags => #{pkg.ldflags.inspect}" end
			if(!pkg.includes.empty?) then mecfile.write ", :includeDirs => MakeRb::UniqPathList[" + pkg.includes.map{|l|"prefix+Pathname.new("+l.to_s.inspect+")"}.join(",") + "]" end
			if(!pkg.libraries.empty?) then mecfile.write", :libraryFiles => MakeRb::UniqPathList[" +
				pkg.libraries.map{|l|
					if(l.is_a?(LShippedLibRef)) then "ShippedLibRef.new(prefix + " + l.name.to_s.inspect + ")" else
						"SysLibRef.new(" + l.name.inspect + ")" end
				}.join(",") + "]"
			end
			mecfile.write("];\n")
			if(!pkg.librariesP.empty? || !pkg.ldflagsP.empty?)
				mecfile.write "\t\t\tsettings[key + {:staticLinking => true}] = MakeRb::Settings["
				args = []
				if(!pkg.ldflagsP.empty?) then args << [":ldFlags => #{pkg.ldflagsP.inspect}"] end
				if(!pkg.librariesP.empty?) then args << [":libraryFiles => [" + pkg.librariesP.map{|l|l.to_s}.join(",") + "]"] end
				mecfile.puts(args.join(",") + "];")
			end
			if(deps[0].length > 0)
				mecfile.puts("\t\t\tsettings[MakeRb::SettingsKey[:mecLibrary => #{mecver}]] = MakeRb::Settings[:mecDependencies => lambda {|m,k| [" + deps[0].join(", ") + "]}];")
			end
			if(deps[1].length > 0)
				mecfile.puts("\t\t\tsettings[MakeRb::SettingsKey[:mecLibrary => #{mecver}, :staticLinking => true]] = MakeRb::Settings[:mecDependencies => lambda {|m,k| [" + deps[1].join(", ") + "]}];")
			end
			
			
			mecfile.puts "\t\tend\n\tend\nend\n"
		}
	end
	def toPC(outpath)
		File.open(pcfile, "r") { |infile|
			File.open(outpath, "w") { |ofile|
				infile.each { |line|
					line.strip!
					
					ofile.puts(if(line =~ /^(Libs\:)(\s*)(.*)(\s*)$/)
						dirs = libraries.select { |lib| lib.is_a?(LShippedLibRef) }.map { |lib| lib.name.dirname.to_s }.uniq.map { |dn| "\"-L${prefix}/#{dn}\"" }
						"Libs: " + ((dirs + ldflags + (libraries.map { |lib| lib.lname })).join(" "))
					elsif(line =~ /^(Libs.private\:)(\s*)(.*)(\s*)$/)
						dirs = librariesP.select { |lib| lib.is_a?(LShippedLibRef) }.map { |lib| lib.name.dirname.to_s }.uniq.map { |dn| "-L${prefix}/#{dn}" }
						"Libs.private: " + ((dirs + ldflagsP + (librariesP.map { |lib| lib.lname })).join(" "))
					elsif(line =~ /^(prefix=)(.*)$/)
						"prefix=@PREFIX@"
					elsif(line =~ /^(Requires:)(.*)$/)
					elsif(line =~ /^(Requires.private:)(.*)$/)
					else
						line
					end)
				}
				if(!deps.empty?)
					d = deps.map { |d| if(d.size == 1) then d[0].name else d[0].name + " " + d[1] + " " + d[2].to_s end }
					ofile.puts("Requires: " + d.join(" "))
				end
				if(!depsP.empty?)
					dp = depsP.map { |d| if(d.size == 1) then d[0].name else d[0].name + " " + d[1] + " " + d[2].to_s end }
					ofile.puts("Requires.private: " + dp.join(" "))
				end
			}
		}
	end
	def getLLibsR(llibs=nil,pkgs=nil)
#		if(@llibs_r == nil)
#			c = false
			if(pkgs == nil)
				pkgs = Set.new
				llibs = Set.new
				c = true
			end
			
			if(!pkgs.include?(self))
				pkgs << self
				libraries.each { |lib| llibs << lib.lname }
				librariesP.each { |lib| llibs << lib.lname }
				
				deps.each  { |d| d[0].getLLibsR(llibs, pkgs) }
				depsP.each { |d| d[0].getLLibsR(llibs, pkgs) }
			end
#			if(c) then @llibs_r = llibs end
#			@llibs_r = llibs
			llibs
#		end
#		@llibs_r
	end
end
