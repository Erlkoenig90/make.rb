#!/usr/bin/env ruby

module MakeRb
	# Loads & parses a makefile.
	# @return An array of dependency rules, each consisting of an 2-element-array, containing arrays of targets and sources (as strings)
	def MakeRb.loadMakeFile(filename)
		res = []
		lines = IO.readlines(filename)
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
		lines.each { |line|
			if(line[0] != "\t")
				i = line.index(':')
				if(i != nil)
					targets = line[0...i].split(" ")
					deps = line[i+1..-1].split(" ")
					res << [targets, deps]
				end
			end
		}
		res
	end
end
