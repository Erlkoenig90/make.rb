#!/usr/bin/env ruby

require 'pkgconfig'

#["gtk+-3.0", "glib-2.0", "atkmm-1.6"].each { |name|
#	mecname = translatePkgName(name)
#	mecpath = (MakeRbExt::ExtManager.getFileName(mecname))
#	back = MakeRbExt::ExtManager.getClassname(Pathname.new(mecpath))
#	puts "#{name} -> #{mecname} in #{mecpath} back #{mecname}"
#}

#exit

pkgs = Packages.loadPC

outdir = Pathname.new("mec")
if(!outdir.directory?)
	outdir.mkdir
end

pkgs.each { |pkgname,pkg|
	pkg.toMEC(outdir)
}
