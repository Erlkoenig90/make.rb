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

require 'set'

module MakeRb
	def MakeRb.collectDepsG(ary,pf,lsym,lcsym)
		puts "collectDepsG([" + ary.map{|a| a}.join(",") + "], #{pf.name}, #{lsym}, #{lcsym}"
		f = ary.map() { |el|
			if(el.used)
				[]
			else
				el.used = true
			
				[el] + if(el.respond_to?(:deps))
					collectDepsG(el.deps, lsym, lcsym)
				else
					[]
				end + if(el.respond_to?(:settings))
					puts "sub-settings"
					puts el.settings
					puts pf
					puts el	
					collectDepsG(el.settings[pf].send(lsym).send(lcsym),pf,lsym,lcsym)
				else
					[]
				end
			end
		}
	end
	def MakeRb.collectIDeps(ary,pf,cx)
		f = MakeRb.collectDepsG(ary,pf,if cx then :cxx else :cc end, :includes).flatten
		f.each { |el| el.used = false }
		f
	end
	def MakeRb.collectLDeps(ary,pf)
		f = MakeRb.collectDepsG(ary,pf,:ld, :libraries).flatten
		f.each { |el| el.used = false }
		f
	end
	def MakeRb.isParentSetting(parent,child)
		(parent == nil || parent == child) ||
			(child.respond_to?(:parentSettings) && MakeRb.isParentSetting(parent, child.parentSettings))
	end
	class Library
		attr_accessor :used
		def initialize
			@used = false
		end
	end
	class SystemLibrary < Library
		attr_reader :name
		def initialize(name)
			@name = name
		end
	end
	class LibraryFile < Library
		attr_reader :path
		def initialize(path_)
			@path = path_
		end
	end
	class Settings < Hash
		def +(otherS)
			if(otherS == nil) then self
			else
				merge(otherS) { |key,own,other|
					if(own.respond_to?(:inheritSettings))
						own.inheritSettings(other)
					elsif(other == nil)
						own
					elsif(own.is_a?(Array) && other.is_a?(Array))
						own + other
					elsif(own.is_a?(String) && other.is_a?(String))
						own
					elsif((own == true || own == false) && (other == true || other == false))  # why is there no "Boolean" class?
						if(own != other)
							raise "Error on merging settings: Two different booleans found (own=#{own}, other=#{other})"
						else
							own
						end
					else
						raise "Error on merging settings: Don't know how to merge #{own.class.name} and #{other.class.name}"
					end
				}
			end
		end
	end
	class UniqPathList < Array
		def inheritSettings(other)
			n = clone
			n.concat(other)
			n.uniq!
			n
		end
	end
	class SettingsKey < Hash
		def +(otherS)
			if(otherS == nil) then self
			else
				merge(otherS) { |key,own,other|
					own
				}
			end
		end
#		def flattenDeps
#			copy = clone
#			copy.each { |key, val|
#				if(val.is_a?(Array))
#					ary = val.clone
#					puts "Settings1: " + ary.map {|l| l.name}.join(", ")
#					set = Set.new(ary)
#					
#					ary.each { |el|
#						if(el.respond_to?(:settingDeps))
#							deps = el.settingDeps
#							deps.each { |dep|
#								if(!set.include?(dep))
#									ary << dep
#									set << dep
#								end
#							}
#						end
#					}
#					copy[key] = ary
#					puts "Settings2: " + ary.map {|l| l.name}.join(", ")
#				end
#			}
#			copy
#		end
	end
	class SettingsMatrix < Settings
		attr_reader :hash
		def initialize(ihash = {})
			@hash = ihash
			@cache = {}
		end
		def []=(key,val)
			@cache.clear
			@hash[key] = val
		end
		def [](keyhash) # O(2^keyhash.size)
			getSettings(keyhash)
		end
		def getSettings(keyhash) # O(2^keyhash.size)
#			puts keyhash
			@cache.fetch(keyhash) {
				keys = keyhash.keys
				@cache[keyhash] = (getSettingsR(keyhash,keys,0) || {})
			}
		end
		def +(otherS)
			SettingsMatrix.new(hash.merge(otherS.hash) { |key,own,other|
				own + other
			})
		end
		def libSupports?(lib, keyhash)
			keys = keyhash.keys
			keyhash[:libraries] = lib
			
			set = getSettingsR(keyhash,keys,0) || {}
			
			keyhash.delete(:libraries)
			
			s = set[:support]
			if(s == nil) then false else s end
		end
		
		def SettingsMatrix.build
			s = nil
			MakeRb::Platform.platforms.map { |key, value|
				sn = value.settings
				s = if(s == nil) then sn else s + sn end
			}
			s + MakeRbLang.settings
		end
		def to_s
			"SettingsMatrix###{object_id} " + hash.to_s
		end
		private
		def getSettingsR(keyhash,keys,depth,nonil = false) # O(2^keys.length)
			if(depth >= keys.length)
				r = @hash[keyhash]
#				p r
#				r
			else
				key = keys[depth]
				obj = keyhash[key]
				orig = obj
				
				settings = nil
				if(obj.is_a?(Array))
					obj.each { |el|
						keyhash[key] = el
						n = getSettingsR(keyhash,keys,depth, true)
						settings = if(settings == nil) then n else settings + n end
					}
					keyhash.delete(key)
					n = getSettingsR(keyhash,keys,depth+1)
					settings = if(settings == nil) then n else settings + n end
				else
					while(!nonil || obj != nil)
						n = getSettingsR(keyhash,keys,depth+1)
						settings = if(settings == nil) then n else settings + n end
						if(obj == nil) then break end
	#					$stdout.write("parent #{obj} to ")
						obj = if(obj.respond_to?(:parentSettings)) then obj.parentSettings else nil end
	#					puts obj
						if(obj == nil)
							keyhash.delete(key)
						else
							keyhash[key] = obj
						end
					end
				end
				keyhash[key] = orig
				settings
			end
		end
	end
end
