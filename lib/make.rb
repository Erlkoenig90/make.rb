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

require 'rubygems'
require 'pathname'
require 'optparse'
require 'trollop'
require 'rbconfig'

require 'makerb_settings'
require 'makerb_platform'
require 'makerb_ext'

module MakeRb
	def MakeRb.isWindows
		@@is_windows ||= (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
	end
	def MakeRb.nullFile
		if(isWindows)
			"NUL"
		else
			"/dev/null"
		end
	end
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
	def MakeRb.removeEmptyDirs(path)
		if(path.directory?)
			if(path.children.inject(true) { |o,c| o && removeEmptyDirs(c) })
				puts "rmdir \"" + path.to_s + "\""
				path.rmdir
				true
			else
				false
			end
		else
			false
		end
	end
	def MakeRb.findWhere(ary,&block)
		i = ary.index { |r| block.call(r) }
		if i == nil
			nil
		else
			ary[i]
		end
	end
	def MakeRb.parseFlags(flagstring)
		# TODO - better parsing here
		flagstring.split(" ")
	end
	class Resource
		attr_accessor :builder, :buildMgr
		def initialize(mgr)
			@builder = nil
			@buildMgr = mgr
			mgr << self
		end
		def name
			raise "Resource#name must be overriden!"
		end
		def initialize2
		end
		def match(m)
			false
		end
		# Used when this resource is used as a builder's dest 
		def destSpecialisations
			SettingsKey[]
		end
		# Used when this resource is used as a builder's src
		def srcSpecialisations
			SettingsKey[]
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
	module ImplicitSrc
	end
	class FileRes < Resource
		include Usable
		
		attr_reader :name, :filename
		def initialize(mgr, fname)
			if(fname.is_a?(String))
				@filename_str = fname
				fname = Pathname.new(fname)
			elsif(fname.is_a?(Pathname))
				@filename_str = fname.to_s
			else
				raise "Invalid argument for FileRes#initialize"
			end
			@name = fname.to_s
			# @filename_str is only used to speed up "match"
			if(is_a?(Generated))
				fname = mgr.builddir + fname
			end
			@filename = fname
			super(mgr)
		end
		def rebuild?(other)
			if(!other.is_a?(FileRes))
				raise other.name + " is not a FileRes"
			end
			own = begin
				File.mtime(buildMgr.effective(filename))
			rescue
				Time.at(0)
			end
			res = File.mtime(other.buildMgr.effective(other.filename)) > own
#			puts "rebuild #{other.filename.to_s} -> #{filename.to_s} => #{res}"
#			if(res) then raise "test" end
			res
		end
		def makePath
			buildMgr.effective(filename).dirname.mkpath
		end
		def clean
			puts "rm -f \"" + @filename.to_s + "\""
			begin
				buildMgr.effective(@filename).unlink
			rescue
			end
		end
		def match_soft(m)
#			puts "match_soft: #{m} == #{@filename_str}"
#			p @filename_str
#			p m
			m.is_a?(String) && (m == @filename_str || ("./" + m) == @filename_str || m == ("./" + @filename_str))
		end
		def match_hard(m)
			if(m.is_a?(Pathname))
				begin
#					false
					(filename.eql? m) || (filename.realdirpath == m.realdirpath)
				rescue
					false
				end
			else
#				false
				@filename_str == m || match_hard(Pathname.new(m))
			end
		end
	end
	class Builder
		attr_reader :sources, :targets, :specialisations, :buildMgr
		def initialize(mgr, spec, src,t)
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

			@specialisations = spec
			@buildMgr = mgr
			
			mgr << self
		end
		def rebuild?
			@targets.inject(false) { |old,target|
				old || @sources.inject(false) { |old2,source|
					old2 || target.rebuild?(source)
				}
			}
		end
		def build
			MakeRb.safePreUse(@sources)
			begin
				MakeRb.safePreBuild(@targets)
			rescue
				@sources.each { |s| s.postUse }
				raise
			end
			
			begin
				cmd = buildDo
#				puts "spawning " + cmd.join(" ")
				if(cmd != nil)
					r, w = IO.pipe
				  pid = spawn(*cmd, :out=>w, :err=>w, r=>:close, :in=>MakeRb.nullFile)
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
end

require 'makerb_buildmgr'
require 'makerb_binary'
require 'makerb_ccxx'
require 'makerb_misc'

