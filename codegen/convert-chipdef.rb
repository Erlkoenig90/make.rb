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

				ofname = "data/linkerscript/gcc/#{dev}.ld"
	
				estack = nil
				doc.root.elements.each { |el|
					if(el.name == "Memory" && el.attributes["Type"] == "SRAM")
						estack = Integer(el.attributes["Start"]) + Integer(el.attributes["Size"])
					end
				}
				estack || raise("#{dev}: Couldn't determine estack address")
				
				puts "#{ifname} => #{ofname}"
				File.open(ofname, "w") { |ofile|
					ofile.puts("ENTRY(Reset_Handler)")
					ofile.puts("_estack = 0x#{estack.to_s(16)}; /* RAM end */")
					
					ofile.puts("MEMORY {")
					doc.root.elements.each { |el|
						if(el.name == "Memory")
							ofile.puts("\t" + el.attributes["Type"] + " : ORIGIN = " + el.attributes["Start"] + ", LENGTH = " + el.attributes["Size"])
						end
					}
					ofile.puts("}")
					
					ofile.write(<<TEXT)
				
_Min_Stack_Size = 0x400;

/* Define output sections */
SECTIONS
{
  /* The startup code goes first into FLASH */
  .isr_vector :
  {
    . = ALIGN(4);
    KEEP(*(.isr_vector)) /* Startup code */
    . = ALIGN(4);
  } >FLASH

  /* The program code and other data goes into FLASH */
  .text :
  {
    . = ALIGN(4);
    *(.text)           /* .text sections (code) */
*(.text*)          /* .text* sections (code) */
*(.rodata)         /* .rodata sections (constants, strings, etc.) */
*(.rodata*)        /* .rodata* sections (constants, strings, etc.) */
*(.glue_7)         /* glue arm to thumb code */
*(.glue_7t)        /* glue thumb to arm code */
*(.eh_frame)

KEEP (*(.init))
KEEP (*(.fini))

. = ALIGN(4);
_etext = .;        /* define a global symbols at end of code */
  } >FLASH


   .ARM.extab   : { *(.ARM.extab* .gnu.linkonce.armextab.*) } >FLASH
    .ARM : {
    __exidx_start = .;
      *(.ARM.exidx*)
      __exidx_end = .;
    } >FLASH

  .preinit_array     :
  {
    PROVIDE_HIDDEN (__preinit_array_start = .);
    KEEP (*(.preinit_array*))
    PROVIDE_HIDDEN (__preinit_array_end = .);
  } >FLASH
  .init_array :
  {
    PROVIDE_HIDDEN (__init_array_start = .);
    KEEP (*(SORT(.init_array.*)))
    KEEP (*(.init_array*))
    PROVIDE_HIDDEN (__init_array_end = .);
  } >FLASH
  .fini_array :
  {
    PROVIDE_HIDDEN (__fini_array_start = .);
    KEEP (*(.fini_array*))
    KEEP (*(SORT(.fini_array.*)))
    PROVIDE_HIDDEN (__fini_array_end = .);
  } >FLASH

  /* Initialized data sections goes into RAM, load LMA copy after code */
  .data : 
  {
    . = ALIGN(4);
    _sdata = .;        /* create a global symbol at data start */
*(.data)           /* .data sections */
*(.data*)          /* .data* sections */

. = ALIGN(4);
_edata = .;        /* define a global symbol at data end */
  } >SRAM AT> FLASH

  /* used by the startup to initialize data */
  _sidata = LOADADDR(.data);

  /* Uninitialized data section */
  . = ALIGN(4);
  .bss :
  {
    /* This is used by the startup in order to initialize the .bss secion */
_sbss = .;         /* define a global symbol at bss start */
__bss_start__ = _sbss;
*(.bss)
*(.bss*)
*(COMMON)

. = ALIGN(4);
_ebss = .;         /* define a global symbol at bss end */
    __bss_end__ = _ebss;
  } >SRAM


  /* Remove information from the standard libraries */
  /DISCARD/ :
  {
    libc.a ( * )
    libm.a ( * )
    libgcc.a ( * )
  }

  .ARM.attributes 0 : { *(.ARM.attributes) }
}
TEXT
				}
			}
			
			
		end
	}
}

