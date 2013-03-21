Gem::Specification.new do |s|
  s.name        = 'make.rb'
  s.version     = '0.0.1'
  s.date        = '2012-08-11'
  s.summary     = "ruby-based generic make system"
  s.description = "make.rb is a build system with special support for cross-compiling and cross-platform development"
  s.authors     = ["Niklas Gürtler"]
  s.email       = 'profclonk@gmx.de'
  s.files       = ["bin/me-config", "lib/make.rb", "lib/makerb_binary.rb", "lib/makerb_buildmgr.rb", "lib/makerb_ccxx.rb", "lib/makerb_ext.rb", "lib/makerb_misc.rb", "lib/makerb_platform.rb", "lib/makerb_settings.rb", "data/linkerscript/gcc/STM32F373CC.ld", "data/linkerscript/gcc/STM32F407VG.ld", "data/startup/gcc/ARMv7M.c"]
  s.bindir		= 'bin'
  s.executables = ['me-config']
  s.required_ruby_version = '>= 1.9.2'
  s.add_runtime_dependency 'trollop', '>= 1.16.2'
  s.homepage	= "http://2g2s.de/make.rb"
  s.license		= 'BSD-3'
end
