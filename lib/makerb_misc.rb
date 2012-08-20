#!/usr/bin/ruby

module MakeRb
	class DepMakeFile < FileRes
		include Generated
		include ImplicitSrc
		def initialize2
#			p filename
			if(buildMgr.effective(filename).file?)
				load
			end
		end
		def load
			lines = IO.readlines(buildMgr.effective(filename))
			i = 0
			while(i < lines.length)
				while lines[i][-1] == "\r" || lines[i][-1] == "\n"
					lines[i]=lines[i][0..-2]
				end
				if(lines[i][-1] == "\\")
					lines[i]=lines[i][0..-2] + lines[i + 1]
					lines.delete_at(i+1)
				else
					i = i + 1
				end
			end
#			p lines
			lines.each { |line|
				if(line[0] != "\t")
					i = line.index(':')
					if(i != nil)
						targets = line[0...i].split(" ")
						deps = line[i+1..-1].split(" ").map { |dName| buildMgr[dName] }.select{ |dep| dep != nil }
						targets.each { |tgName|
							if((target = buildMgr[tgName]) != nil)
								target.builder.sources << self
								target.builder.sources.uniq!
							end
						}
#						puts name + "=[" + builder.sources.map {|s| s.name}.join(", ") + "]<=" + deps.map { |d| d.name }.join(", ")
						builder.sources.concat(deps)
						builder.sources.uniq!
#						puts "==>" + builder.sources.map {|s| s.name}.join(", ")
					end
				end
			}
		end
		def DepMakeFile.auto(src)
			DepMakeFile.new(src.buildMgr, src.filename.sub_ext(".dep"))
		end
	end
end
