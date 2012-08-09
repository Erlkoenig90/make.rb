#!/usr/bin/env ruby

require "platform.rb"

module MakeRb
	def MakeRb.safePreUse(arr)
		for i in 0...arr.size
			begin
				arr[i].preUse
			rescue
				for j in 0...i
					arr[j].postUse
				end
				raise
			end
		end
	end
	def MakeRb.safePreBuild(arr)
		for i in 0...arr.size
			begin
				arr[i].preBuild
			rescue
				for j in 0...i
					arr[j].postBuild
				end
				raise
			end
		end
	end

	class Resource
		attr_accessor :builder
		def initialize
			@builder = nil
		end
		def name
			raise "Resource#name must be overriden!"
		end
	end
	module Usable
		attr_reader :refcount
		def initialize(*x)
			@refcount = 0
			super(*x)
		end
		def preUse
			@refcount += 1
			if(@refcount == 1)
				preUseDo
			end
		end
		def postUse
			@refcount -= 1
			if(@refcount == 0)
				postUseDo
			end
		end
		def preUseDo
		end
		def postUseDo
		end
	end
	module Generated
		attr_reader :locked
		def initialize(*x)
			@locked = false
			super(*x)
		end
		
		def lock
			if(@locked)
				raise name + " is already locked";
			end
			@locked = true
		end
		def unlock
			if(!@locked)
				raise name + " is not locked";
			end
			@locked = false
		end
		
		def preBuild
		end
		def postBuild
		end
	end
	class FileRes < Resource
		include Usable
		
		attr_reader :name, :filename
		def initialize(filename)
			@name = File.basename(filename)
			@filename = filename
			super()
		end
		def rebuild?(other)
			if(!other.is_a?(FileRes))
				raise other.name + " is not a FileRes"
			end
			own = begin
				File.mtime(filename)
			rescue
				Time.at(0)
			end
			File.mtime(other.filename) >= own
		end
	end
	class Builder
		attr_reader :sources, :targets
		def initialize(src,t)
			if(!src.is_a?(Array))
				@sources = [src]
			else
				@sources = src
			end
			
			if(!t.is_a?(Array))
				@targets = [t]
			else
				@targets = t
			end
			@targets.each { |t| t.builder=self }
		end
		def rebuild?
			@targets.inject(false) { |old,target|
				old || @sources.inject(false) { |old2,source|
					old || target.rebuild?(source)
				}
			}
		end
		def build(mgr)
			MakeRb.safePreUse(@sources)
			begin
				MakeRb.safePreBuild(@targets)
			rescue
				@sources.each { |s| s.postUse }
				raise
			end
			
			begin
				cmd = ["./run"] + buildDo(mgr)
#				puts cmd.join(" ")
				if(cmd != nil)
					r, w = IO.pipe
					pid = spawn(*cmd, :out=>w, :err=>w, r=>:close, :in=>"/dev/zero")
					w.close
					
					[cmd, pid, r]
				else
					nil
				end
			rescue
				@sources.each { |s| s.postUse }
				@targets.each { |s| s.postBuild }
				raise
			end
		end
		def buildDo
			raise "Builder#buildDo has to be overriden!"
		end
		def locked
			targets.inject(false) { |o,t| (o || t.locked) }
		end
		def lock
			targets.each { |t| t.lock }
		end
		def unlock
			targets.each { |t| t.unlock }
		end
	end
	class BuildMgr
		class LockedException < Exception
		end
		class Job
			attr_accessor :pid, :pipe, :out, :builder, :cmd
			def initialize()
				@pid = -1
				@pipe = nil
				@out = ""
				@builder = nil
				@cmd = nil
			end
			def set(cmd, pid, pipe, builder)
				@cmd = cmd
				@pid = pid
				@pipe = pipe
				@builder = builder
				@out = ""
			end
			def reset
				@cmd = nil
				@pid = -1
				@out = nil
				@pipe.close
				@builder = nil
			end
			def isset
				@pid != -1
			end
			def read(force = false)
				if(force)
					@out << @pipe.read
				else
					r = 0
					begin
						if(!(@pipe.eof?))
							str = @pipe.read_nonblock(8*1024)
							r = str.length
							@out << str
						end
					end while r > 0 && !(@pipe.eof?)
				end
			end
			def eof?
				@pipe.eof?
			end
		end
		
		attr_reader :jobs, :platform
		def initialize()
			@jobs = 4
			@platform = Platform.new("x86_64-unknown-linux-gnu", "x86_64-unknown-linux-gnu-")
		end
		def build(targets)
			procs = Array.new(@jobs) { |i| Job.new }
			jcount = 0
			
			run = true
			while(run)
#				puts "== ITERATION =="
				# Start new tasks
				while(jcount < procs.length)
					builder = nil
					locked = false
					targets.each { |target|
						begin
							builder = find(target)
						rescue LockedException
							locked = true
						end
						if (builder != nil)
							break
						end
					}
					if(builder == nil)
#						puts "Nothing to build found"
						if(!locked)
							run = false
						else
							if(jcount == 0)
								puts "Error: jcount = 0, but locks where found"
							end
						end
						break
					else
						builder.lock
						res = builder.build(self)
						if(res != nil)
							jcount += 1
							for i in 0...procs.length
								if(!procs[i].isset)
									procs[i].set(res[0], res[1], res[2], builder)
									puts "[" + i.to_s + "] " + procs[i].cmd.join(" ")
									break
								end
							end
						end
					end
				end
				
				if(jcount == 0)
					puts "Nothing to do anymore."
					break
				end
				
				# Wait for input
				fds = procs.select{ |j| j.isset }.map { |j| j.pipe }

				if(fds.length == 0)
					puts "Error: fds.length = 0. jcount = " + jcount.to_s
					exit
				end
				
#				$stdout.write "==SELECT== "
#				before = Time.now
				IO.select(fds)
#				delay = Time.now - before
#				puts delay.to_s
				
				forcewait = false
				for i in 0...procs.length
					if(procs[i].isset)
						# Read input data
						procs[i].read(forcewait)
						
						# Exited or force wait
						if(forcewait || procs[i].eof?)
							begin
								Process.waitpid(procs[i].pid)
							end while (!($?.exited?))
							
							if($?.exitstatus != 0)
								puts "Command failed:"
								puts procs[i].cmd.join(" ")
								puts procs[i].out
								run = false
								forcewait = true
							end
							
							procs[i].builder.unlock
							procs[i].reset
							jcount -= 1
						end
					end
				end
			end
		end
		def find(target,depth=0)
			indent = ("  "*depth)
#			puts indent + "find(" + target.name + ")"
			if(target.is_a?(Generated))
				if(target.builder.locked)
#					puts indent + "locked"
					raise LockedException.new
				else
					found = nil
					ex = nil
					target.builder.sources.each { |s|
						begin
							found = find(s,depth+1)
						rescue LockedException
							ex = $!
						end
						
						if(found != nil)
							break
						end
					}
					if(ex != nil && found == nil)
						raise ex
					end
					if(found == nil)
						if(target.builder.rebuild?)
							found = target.builder
						end
					end
					found
				end
			else
				nil
			end
		end
	end
end

require "makerb_binary"
require "makerb_ccxx"

if false
s1 = MakeRbCCxx::CFile.new("foo.c")
s2 = MakeRbCCxx::CxxFile.new("bar.cc")
o1 = MakeRbCCxx::CObjFile.new("foo.o")
o2 = MakeRbCCxx::CxxObjFile.new("bar.o")

c1 = MakeRbCCxx::Compiler.new(s1,o1)
c2 = MakeRbCCxx::Compiler.new(s2,o2)

e1 = MakeRbBinary::DynLibrary.new("foo")

l1 = MakeRbCCxx::Linker.new([o1, o2],e1)

mgr = MakeRb::BuildMgr.new()
mgr.build([e1])
end

Dir.open(".") { |d|
	objs = []
	d.each { |f|
		if (f != "." && f != ".." && /\.cc$/.match(f))
#			puts f
			c = MakeRbCCxx::CxxFile.new(f)
			o = MakeRbCCxx::CxxObjFile.new(File.basename(f, ".cc") + ".o")
			cl = MakeRbCCxx::Compiler.new(c, o)
			
			objs << o
		end
	}
	lib = MakeRbBinary::DynLibrary.new("bar.so")
	lin = MakeRbCCxx::Linker.new(objs, lib)
	
	mgr = MakeRb::BuildMgr.new()
	mgr.build([lib])
}

