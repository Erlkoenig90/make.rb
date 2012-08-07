#!/usr/bin/env ruby

module MakeRb
	def MakeRb.safePreUse(arr)
		for i in 0...arr.size
			begin
				arr[i].preUse
			rescue
				for j in 0...i
					arr[j].postUse
				end
				throw $!
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
				throw $!
			end
		end
	end

	class Resource
		attr_accessor :builder
		def initialize
			@builder = nil
		end
		def name
			throw "Resource#name must be overriden!"
		end
	end
	module Usable
		attr_reader :refcount
		def initialize
			@refcount = 0
		end
		def preUse
			@refcount++
			if(@refcount == 1)
				preUseDo
			end
		end
		def postUse
			@refcount--
			if(@refcount == 0)
				postUseDo
			end
		end
	end
	module Generated
		attr_reader :locked
		def initialize
			@locked = false
		end
		
		def lock
			if(@locked)
				throw name + " is already locked";
			end
			@locked = true
		end
		def unlock
			if(!@locked)
				throw name + " is not locked";
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
		end
		def rebuild?(other)
			if(!other.is_a?(FileRes))
				throw other.name + " is not a FileRes"
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
		def initialize(sources,targets)
			if(!sources.is_a?(Array))
				@sources = [sources]
			else
				@sources = sources
			end
			
			if(!targets.is_a?(Array))
				@targets = [targets]
			else
				@targets = targets
			end
			targets.foreach { |t| t.addBuilder(self) }
		end
		def rebuild?
			@targets.inject(false) { |old,target|
				old || @sources.inject(false) { |old2,source|
					old || target.rebuild(source)
				}
			}
		end
		def build
			MakeRb.safePreUse(@sources)
			begin
				MakeRb.safePreBuild(@targets)
			rescue
				@sources.each { |s| s.postUse }
				throw $!
			end
			
			begin
				cmd = buildDo
				puts cmd.join(" ")
				if(cmd != nil)
					r, w = IO.pipe
					pid = spawn(*cmd, :out=>w, :err=>w, r=>:close, :in=>"/dev/zero")
					w.close
					
					[r, pid]
				else
					nil
				end
			rescue
				@sources.each { |s| s.postUse }
				@targets.each { |s| s.postBuild }
				throw $!
			end
		end
		def buildDo
			throw "Builder#buildDo has to be overriden!"
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
		class LockedException
		end
		
		attr_reader :builders, :jobs
		def initialize(builders)
			@builders = builders
			@jobs = 4
		end
		def build(targets)
			procs = Array.new(@jobs, nil)
			jcount = 0
			
			run = true
			while(run)
				# Start new tasks
				while(jcount < @jobs)
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
						if(!locked)
							run = false
						end
						break
					else
						builder.lock
						res = builder.build
						if(res != nil)
							jcount++
							for i in 0...@jobs
								if(procs[i] == nil)
									procs[i] = res
									break
								end
							end
						end
					end
				end
				
				
			end
		end
		def find(target)
			if(target.is_a?(Generated))
				if(target.builder.locked)
					throw new LockedException
				else
					found = nil
					ex = nil
					target.builder.sources.each { |s|
						begin
							found = find(s)
						rescue LockedException
							ex = $!
						end
						
						if(found != nil)
							break
						end
					}
					if(ex != nil && found == nil)
						throw ex
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

require "./makerb_binary"
require "./makerb_ccxx"

s1 = MakeRbCCxx::CFile.new("foo.c")
s2 = MakeRbCCxx::CxxFile.new("bar.cc")
o1 = MakeRbCCxx::CObjFile.new("foo.o")
o2 = MakeRbCCxx::CxxObjFile.new("bar.o")

c1 = MakeRbCCxx::Compiler.new(s1,o1)
c2 = MakeRbCCxx::Compiler.new(s2,o2)

e1 = MakeRbBinary::DynLibrary.new("foo")

l1 = MakeRbCCxx::Linker.new([o1, o2],e1)

c1.build
c2.build
l1.build
