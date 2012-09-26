#!/usr/bin/env ruby

require 'make.rb'
require 'pathname'
require 'set'

puts "module MakeRbExt"

$pkgnames = ["gtk+-3.0", "gtk-vnc-2.0"]
$generated = Set[]
$settings = ""


def translatePkgName(pkg)
	pkgs = pkg
	while(pkgs.length > 2 && pkgs[-2..-1] == ".0")
		pkgs = pkgs[0...-2]
	end
	MakeRbExt::ExtManager.getClassname(Pathname.new(pkgs))
end

def pkg_cconf(str, vars)
#	p vars
	str.gsub(/(\$\{)([^\}]*)(\})/) { |name|
		name = name[2 .. -2]
#		puts "#{name} ---> #{vars[name]}"
		vars[name]
	}
#	str.gsub(/(\$\{)/) { |name| vars[name] }
end

def outpkg(pkg)
	if(pkg == nil)
		raise "foo"
	end
	if(!$generated.include?(pkg))
		$generated << pkg
	#	puts pkg
#		deps = `pkg-config --print-requires #{pkg}`.strip.split("\n")
#		deps.each { |dep| outpkg(dep) }
#		deps = deps.map{ |p| translatePkgName(p.strip) }.select { |p| p != pkg }

		pkgs = translatePkgName(pkg)
		ver = `pkg-config --modversion #{pkg}`.strip
	#	puts ver
		vera = ver.split(".").map { |n| n.to_i }
	
		lib = pkgs
		libver = pkgs + "_" + vera.join("_")
	
		
		cflags = []
		ldflags = []
		deps = []
		vars = {}
		File.open("/usr/lib/pkgconfig/" + pkg + ".pc") { |f|
			f.each { |line|
				if(m = /^(Cflags\:)(\s*)(.*)(\s*)$/.match(line))
#					p m
					cflags = MakeRb.parseFlags(pkg_cconf(m[3], vars))
				elsif(m = /^(Libs\:)(\s*)(.*)(\s*)$/.match(line))
					ldflags = MakeRb.parseFlags(pkg_cconf(m[3], vars))
				elsif(m = /^(Requires\:)(\s*)(.*)(\s*)$/.match(line))
					deps = []
					str = m[3].strip
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
					words << str[l..-1]
					
#					p words
					i = 0
					while(i < words.length)
						k = i
						if(i+2 < words.length && [">=","<="].include?(words[i+1]))
							deps << translatePkgName(words[i]) + " " + words[i+1] + " [" + words[i+2].gsub(".", ",") + "]"
							i = i + 3
						elsif(i+2 < words.length && "=" == words[i+1])
							deps << translatePkgName(words[i]) + "_" + words[i+2].gsub(".","_")
							i = i + 3
						else
							deps << translatePkgName(words[i]) + ".latest"
							i = i + 1
						end
						outpkg(words[k])
					end
				elsif(m = /^([^=]*)=(.*)$/.match(line))
					vars[m[1]] = pkg_cconf(m[2], vars)
				end
			}
		}
		
		libdirs = []
		libfiles = []
		ldflags.delete_if { |flag|
			if(flag[0..1] == "-L")
				libdirs << flag[2..-1]
				true
			elsif(flag[0..1] == "-l")
				libfiles << "lib" + flag[2..-1]
				true
			else
				false
			end
		}
		
		l_ext = [".so", ".a", ".o"]
		libfiles.map! { |f|
			file = nil
			libdirs.each { |d|
				if ((file = l_ext.index { |ext| File.exists?(d + "/" + f + ext) }) != nil)
					file = d + "/" + f + l_ext[file]
					break
				end
			}
			"Pathname.new(\"" + (file|| raise("Couldn't find library file `#{f}'")) + "\")"
		}
		
		includes = []
		cflags.delete_if { |flag|
			if(flag[0..1] == "-I")
				includes << "Pathname.new(\"" + flag[2..-1] + "\")"
				true
			else
				false
			end
		}
		
		puts "\tlibrary :#{lib}\n"
		puts ("\tlibver :#{libver}, #{lib}, version:" + vera.inspect + if(deps.length>0) then ", deps:[" + deps.join(",") + "]" else "" end + "\n\n")
#		p vars
#		cflags = MakeRb.parseFlags(`pkg-config --cflags #{pkg}`).inspect
#		ldflags = MakeRb.parseFlags(`pkg-config --libs #{pkg}`).inspect
		
		$settings = $settings + "\n" +																					# , :language => MakeRbLang::C
"\t\t\tsettings[SettingsKey[:libraries => #{libver}, :platform => MakeRb::Platform.native, :toolchain => MakeRbCCxx.tc_gcc, :language => MakeRbLang::C]] =
	\t\t\tSettings[:support => true, :clFlags => #{cflags}, :ldFlags => #{ldflags}" + 
		if(!includes.empty?) then ", :includeDirs => MakeRb::UniqPathList[" + includes.join(",") + "]" else "" end + 
			if(!libfiles.empty?) then ", :libraryFiles => MakeRb::UniqPathList[" + libfiles.join(",") + "]" else "" end + "];\n"

	end
end

$pkgnames.each { |pkg|
	if(pkg == nil)
		raise "blubb"
	end
	outpkg (pkg)
}

puts "\tmodule GtkDesc\n\t\tdef GtkDesc.register(settings)"
puts $settings
puts "\t\tend\n\tend\nend\n"

