#!/usr/bin/env ruby

require './pkgconfig'

pkgs = Packages.loadPC

outdir = Pathname.new("mec")
if(!outdir.directory?)
	outdir.mkdir
end

pkgs.each { |pkgname,pkg|
	pkg.toMEC(outdir + (pkg.name + ".rb"))
}
