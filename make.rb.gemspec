Gem::Specification.new do |s|
  s.name        = 'make.rb'
  s.version     = '0.0.1'
  s.date        = '2012-08-11'
  s.summary     = "ruby-based generic make system"
  s.description = "make.rb is a cross-platform build system like make, where everything, is configured in ruby objects to gain more flexibility"
  s.authors     = ["Niklas Gürtler"]
  s.email       = 'profclonk@gmx.de'
  s.files       = ["lib/make.rb", "lib/makerb_ccxx.rb", "lib/makerb_settings.rb", "lib/makerb_binary.rb", "lib/makerb_platform.rb"]
  s.add_runtime_dependency 'trollop', '>= 1.16.2'
  s.homepage	= "http://2g2s.de/make.rb"
end
