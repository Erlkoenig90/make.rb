#!/usr/bin/env ruby

require 'set'

module MakeRb
	def MakeRb.isParentSetting(parent,child)
		(parent == nil || parent == child) ||
			(child.respond_to?(:parentSettings) && MakeRb.isParentSetting(parent, child.parentSettings))
	end
	class Settings < Hash
		def +(otherS)
			if(otherS == nil) then self
			else
				merge(otherS) { |key,own,other|
					Settings.merge(own, other)
				}
			end
		end
		def add(otherS)
			merge!(otherS) { |key,own,other|
				Settings.merge(own, other)
			}
		end
		def Settings.merge(own, other)
			if(own.respond_to?(:inheritSettings))
				own.inheritSettings(other)
			elsif(other == nil)
				own
			elsif(own.is_a?(Array) && other.is_a?(Array))
				own + other
			elsif(own.is_a?(String) && other.is_a?(String))
				own
			elsif(own.is_a?(Hash) && other.is_a?(Hash))
				own.merge(other) { |k,w,o| Settings.merge(w,o)}
			elsif((own == true || own == false) && (other == true || other == false))  # why is there no "Boolean" class?
				if(own != other)
					raise "Error on merging settings: Two different booleans found (own=#{own}, other=#{other})"
				else
					own
				end
			elsif(own.is_a?(Proc) && other.is_a?(Proc))
				lambda { Settings.merge(own.call(), other.call()) }
			else
				raise "Error on merging settings: Don't know how to merge #{own.class.name} and #{other.class.name}"
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
	end
	class SettingsMatrix
		attr_reader :hash
		def initialize(ihash = {})
			@hash = ihash
			@cache = {}
		end
		def self.[](h)
			nh = {}
			h.each { |k,v| nh[SettingsKey[k]] = Settings[v]; }
			self.new(nh)
		end
		def []=(key,val)
			@cache.clear
			@hash[key] = val
		end
		def [](keyhash) # O(2^keyhash.size)
			getSettings(keyhash)
		end
		def +(otherS)
			SettingsMatrix.new(hash.merge(otherS.hash) { |key,own,other|
				own + other
			})
		end
		def add(otherS)
			@hash.merge!(otherS.hash) { |key, own, other|
				own.add(other)
				own
			}
			@cache.clear
		end
		def addSpecialized(otherS, addkey)
			otherS.hash.each { |k,v|
				nk = addkey+k
				s = hash[nk]
				if(s == nil)
					hash[nk] = v
				else
					s.add(v)
				end
			}
			@cache.clear
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
		# Returns the {SettingsMatrix#getSettings settings} for the platform we are currently running on
		def nativeSettings
			getSettings({:platform => Platform.native})
		end
		def getSettings(keyhash) # O(2^keyhash.size)
	#			puts keyhash
			@cache.fetch(keyhash) {
				woArrays = keyhash.select {|k,v| !v.is_a?(Array) }
				expanded = keyhash.clone
				expanded.each { |k,v|
					if(v.is_a?(Array))
						collected = Set[]
						queue = v.clone
						while(!queue.empty?)
							el = queue.first
							if(!collected.include?(el))
								collected << el
								if(el.respond_to?(:settingDeps))
									deps = el.settingDeps(self,woArrays)
									queue.concat(deps)
								end
							end
							queue.delete_at(0)
						end
						expanded[k] = collected.to_a
					end
				}
				
				keys = expanded.keys
				@cache[keyhash] = (getSettingsR(expanded,keys,0) || {})
			}
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
						obj = if(obj.respond_to?(:parentSettings)) then obj.parentSettings
							elsif(obj.is_a?(Class)) then obj.superclass else nil end
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
