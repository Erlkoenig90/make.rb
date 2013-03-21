ENTRY(Reset_Handler)
_estack = 0x20008000; /* RAM end */
MEMORY {
	SRAM : ORIGIN = 0x20000000, LENGTH = 0x8000
	FLASH : ORIGIN = 0x08000000, LENGTH = 0x40000
}
				
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
