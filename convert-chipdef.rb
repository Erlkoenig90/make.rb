#!/usr/bin/ruby
require "rexml/document"
require 'set'
require 'fileutils'

$devices=[]
$xml = "libs/chipdef/xml"

def mkDirFile(file)
	dir = File.dirname(file)
	if(!File.directory?(dir))
		puts "Creating directory #{dir}"
		FileUtils.mkdir_p(dir)
	end
end


Dir.open($xml) { |dir|
	dir.each { |xmlname|
		m=/^(.*)(\.xml)$/.match(xmlname)
		if(m != nil)
			dev = m[1]
			$devices << dev	
	
			ofname_nvicc = "data/isr-vector/gcc/#{dev}.c"
			ifname = "#{$xml}/#{xmlname}"

			mkDirFile(ofname_nvicc)
			
			File.open(ifname) { |file|
				doc = REXML::Document.new file
				
				arm_int = [[1, "Reset"],
					[2, "NMI"],
					[3, "HardFault"],
					[4, "MemManage"],
					[5, "BusFault"],
					[6, "UsageFault"],
					[7, nil], [8, nil], [9, nil], [10, nil],
					[11, "SVCall"],
					[12, "DebugMon"],
					[13, nil],
					[14, "PendSV"],
					[15, "SysTick"]]
	
				puts "#{ifname} => #{ofname_nvicc}"
				File.open(ofname_nvicc, "w") { |ofile|
					ofile.puts "#include <stdint.h>\n#ifdef __cplusplus\n\textern \"C\" {\n#endif\n\n"
					ofile.puts "void Default_Handler (void) {\n\tasm volatile (\"bkpt\");\n\twhile (1); // Read IPSR (lowest byte of xPSR) to get IRQ Number.\n}\n"
					
					
					sorted = doc.root.elements.select { |el| el.name=="IRQ" }.
						map { |el| [el.attributes["name"], el.attributes["num"].to_i, el.attributes["desc"]] }.
						select { |name,num,desc| num >= 0 }.sort { |a,b| a[1] <=> b[1] }
					h = {}
					sorted.each { |i| h[i[1]] = i }
					
					arm_int.each { |i|
						if(i[1] != nil)
							ofile.puts("void #{i[1]}_Handler ()  __attribute__ ((weak, used, alias (\"Default_Handler\")));")
						end
					}
					sorted.each { |name,num,desc|
						ofile.puts("void #{name}_IRQHandler ()  __attribute__ ((weak, used, alias (\"Default_Handler\")));")
					}
					
					ofile.puts "extern uint32_t _estack __attribute__((weak));"
					ofile.puts "uint32_t isr_vector [] __attribute__ ((used, section (\".isr_vector\"))) = {(uint32_t) &_estack,"
					for i in 0..14 do
						if(arm_int[i][1] != nil)
							ofile.write("(uint32_t) &#{arm_int[i][1]}_Handler,")
						else
							ofile.write("0,")
						end
					end
					
					for i in 0..sorted[-1][1]
						if(h.include?(i))
							name, num, desc = h[i]
							ofile.write "(uint32_t) &#{name}_IRQHandler,"
						else
							ofile.write "0,"
						end
					end
					
					ofile.puts "};\n"
					ofile.puts "#ifdef __cplusplus\n\t}\n#endif\n\n"
				}

			}
		end
	}
}

