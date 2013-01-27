#!/usr/bin/env ruby

require 'fileutils'

require './pkgconfig'

pkgs = Packages.loadPC

outdir = Pathname.new("pc")
if(!outdir.directory?)
	outdir.mkdir
end

pkgs.each { |pkgname,pkg|
	bak = pkg.pcfile.sub_ext(".pc.bak")
	if(!bak.file?)
		FileUtils::copy(pkg.pcfile, bak)
	end
	orig = pkg.pcfile
	pkg.pcfile = bak
	pkg.toPC(orig)
}
