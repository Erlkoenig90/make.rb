#!/usr/bin/ruby

require 'pathname'
require 'make.rb'

$pc_dirs = [Pathname.new("/usr/lib/pkgconfig"), Pathname.new("/usr/share/pkgconfig/")] + ((ENV["PKG_CONFIG_PATH"] || "").split(":").map{|f| Pathname.new(f)})
$blacklist = ["avahi-qt3.pc"] #, "gnutls-dane.pc", "cogl-pango-2.0-experimental.pc"]
$library_path = [Pathname.new("/usr/lib"), Pathname.new("/lib")] + ((ENV["LD_LIBRARY_PATH"] || "").split(":").map{|f| Pathname.new(f)})


def translatePkgName(pkg)
	MakeRbExt::ExtManager.getClassname(Pathname.new(pkg))
end

def getPkgFiles(file)
	pkg = `pacman -Qqo #{file}`
	`pacman -Qql #{pkg}`.split("\n").map{|f| f.strip }.select { |f| File.file?(f) }
end

class Packages < Hash
	def initialize(d)
		@pcDirs = d
		super
	end
	def self.loadPC(dirs = $pc_dirs, blacklist = $blacklist)
		pkgs = self.new(dirs)
		errors = ""
		dirs.each { |dirname|
			dirname.opendir { |d|
				d.each { |pc|
					if(pc != "." && pc != ".." && File.extname(pc) == ".pc")
						if(!blacklist.include?(pc))
							path = dirname + pc
							if(path.file?)
								begin
									pkg = Package.fromPC(pkgs, path)
									pkgs[pkg.name] = pkg
								rescue
									errors << "Load failed: #{$!}\n"
								end
							end
						end
					end
				}
			}
		}
		if(!errors.empty?)
			puts errors
		end
		pkgs
	end
	def getPCFile(name)
		@pcDirs.each { |dirname|
			path = dirname + (name + ".pc")
			if(path.file?)
				return path
			end
		}
		raise("No .pc file for #{name} found")
	end
	def getDep (pkgname, depth, operator=nil, version=nil)
#		p self
#		p pkgname
		f = fetch(pkgname, nil)
#		p f
		if(f == nil)
			f = Package.fromPC(self, getPCFile(pkgname), depth+1)
			self[pkgname] = f
		end
#		p f.version
		if((operator == nil) || (operator == "=" && f.version == version) || (operator == ">" && f.version > version) || (operator == ">=" && f.version >= version) || (operator == "<" && f.version < version) || (operator == "<=" && f.version <= version))
			f
		else
			raise "Package #{pkgname} doesn't satisfy condition #{operator} #{version}"
		end
	end
end

class Version < Array
	include Comparable
end

class Package
	attr_accessor :name, :includes, :version, :deps, :depsP, :pcfile, :libraries, :librariesP, :ldflags, :ldflagsP, :cflags
	def initialize(s, name_, ver, pcfile_, deps_, depsP_, libs, libsP, ldflags_, ldflagsP_, cflags_, inc)
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
	end
	def self.pkg_cconf(str, vars)
		#	p vars
		str.gsub(/(\$\{)([^\}]*)(\})/) { |name|
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
	def self.findLibfiles(exts, dirs, files)
#		puts "findLibfiles(#{exts}, #{dirs}, #{files})"
		d = ($library_path + dirs).uniq
		files.map { |f|
			file = nil
#			puts "dirs: " + dirs.inspect
			d.each { |d|
				if ((file = exts.index { |ext|
					p = (d + (f + ext))
#					p p	
					p.file?
				}) != nil)
					file = d + (f + exts[file])
					break
				end
			}
			file || raise("Library file `#{f}' not found")
		}
	end
	def self.fromPC(pkgs, path, depth=0)
		pkgname = path.basename.sub_ext("").to_s
		puts ("  " * depth) + "loading #{pkgname}"
		
		version = nil
		cflags = []
		ldflags = []
		ldflagsP = []
		deps = []
		depsPrivate = []
		vars = {}
		File.open(path) { |f|
			f.each { |line|
				if(m = /^(Cflags\:)(\s*)(.*)(\s*)$/.match(line))
					#					p m
					cflags = MakeRb.parseFlags(pkg_cconf(m[3], vars))
				elsif(m = /^(Libs\:)(\s*)(.*)(\s*)$/.match(line))
					ldflags = MakeRb.parseFlags(pkg_cconf(m[3], vars))
				elsif(m = /^(Version\:)(\s*)(.*)(\s*)$/.match(line))
					version = decodeVersion(pkg_cconf(m[3], vars))
				elsif(m = /^(Libs.private\:)(\s*)(.*)(\s*)$/.match(line))
					ldflagsP = MakeRb.parseFlags(pkg_cconf(m[3], vars))
				elsif((m1 = /^(Requires\:)(\s*)(.*)(\s*)$/.match(line)) || (m2 = /^(Requires.private\:)(\s*)(.*)(\s*)$/.match(line)))
					depsProxy = if(/^(Requires\:)(\s*)(.*)(\s*)$/.match(line))
						m = m1
						deps
					else
						m = m2
						depsPrivate
					end
					#					p m
					str = pkg_cconf(m[3], vars).strip
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
								depsProxy << [pkgs.getDep(words[i], depth, words[i+1], decodeVersion(words[i+2])), words[i+1], words[i+2]]
							end
							i = i + 3
						else
#							puts "#{pkgname} requiring in #{words[i]}"
							if (words[i] != "pkg-config")
								depsProxy << [pkgs.getDep(words[i], depth)]
							end
							i = i + 1
						end
					end
				elsif(m = /^([^=]*)=(.*)$/.match(line))
					vars[m[1]] = pkg_cconf(m[2], vars)
				end
			}
		}
		includes = []
		cflags.delete_if { |flag|
			if(flag[0..1] == "-I")
				includes << Pathname.new(flag[2..-1])
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
		
		begin
			libs = findLibfiles([".so", ".a", ".o"], *ldflags_d)
			libsP = findLibfiles([".a", ".o", ".so"], *ldflagsP_d)
		rescue
			raise pkgname + ": " + $!.to_s
		end
		
		if(version == nil)
			raise "No version for package #{pkgname} (#{path}) given"
		end
		Package.new(pkgs, pkgname, version, path, deps, depsPrivate, libs, libsP, ldflags, ldflagsP, cflags, includes)
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
	def toMEC(mecpath)
		mecpath.open("w") { |mecfile|
			pkg = self
			mecfile.puts "module MakeRbExt"
			mecname = translatePkgName(pkg.name)
			mecver = mecname + "_" + pkg.version.join("_")
			deps = [pkg.deps,pkg.depsP].map { |d|
				d.map { |dep|
					op = if(dep[1] == "=") then "==" else dep[1] end;
					translatePkgName(dep[0].name) + (if(dep.size == 1) then ".latest" else " " + op + " " + Package.decodeVersion(dep[2]).inspect end)
				}
			}  
			
			mecfile.puts "\t# file: " + pkg.pcfile.to_s
			
			mecfile.puts "\tlibrary :#{mecname}\n"
			mecfile.puts("\tlibver :#{mecver}, #{mecname}, version:" + pkg.version.inspect)
			
			mecfile.puts "\tloadExt " + ((pkg.deps + pkg.depsP).map { |d| d[0].name.inspect }).join(",") 
	
			mecfile.puts "\tmodule #{mecname}Desc\n\t\tdef #{mecname}Desc.register(settings)"
			
			mecfile.write "\t\t\tkey = MakeRb::SettingsKey[:libraries => #{mecver}, :platform => MakeRb::Platform.native, :toolchain => MakeRbCCxx.tc_gcc, :language => MakeRbLang::C]\n"
			mecfile.write "\t\t\tsettings[key] =
		\t\t\tMakeRb::Settings[:support => true"
			if(!pkg.cflags.empty?) then mecfile.write ", :clFlags => #{pkg.cflags.inspect}" end
			if(!pkg.ldflags.empty?) then mecfile.write ", :ldFlags => #{pkg.ldflags.inspect}" end
			if(!pkg.includes.empty?) then mecfile.write ", :includeDirs => MakeRb::UniqPathList[" + pkg.includes.map{|l|l.to_s.inspect}.join(",") + "]" end
			if(!pkg.libraries.empty?) then mecfile.write", :libraryFiles => MakeRb::UniqPathList[" + pkg.libraries.map{|l|l.to_s.inspect}.join(",") + "]" end
			mecfile.write("];\n")
			if(!pkg.librariesP.empty? || !pkg.ldflagsP.empty?)
				mecfile.write "\t\t\tsettings[key + {:staticLinking => true}] = MakeRb::Settings["
				args = []
				if(!pkg.ldflagsP.empty?) then args << [":ldFlags => #{pkg.ldflagsP.inspect}"] end
				if(!pkg.librariesP.empty?) then args << [":libraryFiles => [" + pkg.librariesP.map{|l|l.to_s.inspect}.join(",") + "]"] end
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
end
