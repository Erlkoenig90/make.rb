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
