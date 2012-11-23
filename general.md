# @title make.rb general
# About make.rb

make.rb is a ruby-based buildsystem, i.e. a program for running the right external program at the right time,
specially suited for, but not limited to, compilers and other command line based programs that automatically process
data from a source and produce a result at a given destination (e.g. files). In make.rb's context we will call
the programs 'builders'. Similar to other build systems, such as [GNU make](http://www.gnu.org/software/make/),
make.rb

* checks modification timestamps of files, to ensure builders are only run when needed
* uses a script file (whose name is usually 'make.rb' but can be chosen arbitrarily) in the project's directory
to configure its behaviour (similar to make's makefiles)
* runs multiple builders at the same time to make use of multi-core systems

But unlike other build systems, make.rb

* doesn't just execute commands from the configuration file, but has a notion of different builders - e.g. knows
what a C/C++ compiler is, constructs the compiler's command line from data given as ruby objects, and thereby allows
to use **multiple compilers**. That means by just specifying a command line switch to make.rb, your program will be
compiled by the selected compiler, without the need to write anything specific to any compiler in your make.rb configuration file.
* also has a notion of **platforms** (e.g. linux-x86, linux-amd64, windows-x86, the STM32F4 microcontroller, etc.).
Again via a command line switch, the platform to be compiled for can be selected. make.rb then automatically uses
the correct compiler switches for the desired platform.
* maintains settings (like compiler flags, include paths, etc.) in a multi-dimensional hash, instead of simple variables
as e.g. the "CCFLAGS" variable in make. That means, these settings can be configured per-platform, per-compiler,
per-target, etc. These are managed in a uniform way for easy access.
* has a system to load external, system-wide and per-user configuration files ("MEC" = make.rb external
configuration), which are to be used to describe libraries and their dependencies. These settings can again be
specified per platform, per compiler, etc., so you can have multiple versions of a library installed for different
platforms, and make.rb will use the correct one for the currently selected platform. This makes mec a more powerful
and flexible **replacement for [pkg-config](http://www.freedesktop.org/wiki/Software/pkg-config)**.


These features make make.rb specially useful for **cross-platform** and **cross-compiling** applications.
That doesn't mean make.rb makes your application run magically on another platform than it was written for - make.rb
just makes sure the correct compiler is called with the correct arguments, your code still needs to address every
platform specially.

However, make.rb is still in an experimental state, with currently few builders included and only support
for [GCC](http://gcc.gnu.org) - but the overall structure is in place, facilitating fixing these holes.

### Using make.rb
See {file:docs/using.md using make.rb}

### License
See {file:LICENSE}

### Author
{profclonk@gmail.com Niklas Gürtler}

Planned/missing features are (TODO-List):

* Pass selected platform to compiled code via -D
* A simple Gtk+ UI displaying the builder's output in a way suitable for concurrent processing
* Recompiling C/C++ files when included header files change (using the -M* flag of GCC). Some code for this is
written, but needs to be fixed, optimized & integrated
* Support for the Microsoft C/C++ compiler, AVR, for the IAR compilers, AVRmaybe for javac, the Java compiler.
* Including linkerscripts
* Support for git (querying the current version number/tag)
* Eclipse plugin
* Defining files to be installed by the program, so make.rb can generate packages for linux package managers and
possibly windows setup files
* Calling external make.rb configuration scripts to include their resource's
* Custom command line settings
* Packages for package systems
* Complete the documentation
* Various TODO's in the code
