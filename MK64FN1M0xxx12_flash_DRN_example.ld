/*
** DRN linker control file for XXX2, non-bootload (debuggable) version - June 2017
**
** ###################################################################
**     Processors:          MK64FN1M0VDC12
**                          MK64FN1M0VLL12
**                          MK64FN1M0VLQ12
**                          MK64FN1M0VMD12
**
**     Compiler:            GNU C Compiler
**     Reference manual:    K64P144M120SF5RM, Rev.2, January 2014
**     Version:             rev. 2.8, 2015-02-19
**     Build:               b151217
**
**     Abstract:
**         Linker file for the GNU C Compiler
**
**     Copyright (c) 2015 Freescale Semiconductor, Inc.
**     All rights reserved.
**
**     Redistribution and use in source and binary forms, with or without modification,
**     are permitted provided that the following conditions are met:
**
**     o Redistributions of source code must retain the above copyright notice, this list
**       of conditions and the following disclaimer.
**
**     o Redistributions in binary form must reproduce the above copyright notice, this
**       list of conditions and the following disclaimer in the documentation and/or
**       other materials provided with the distribution.
**
**     o Neither the name of Freescale Semiconductor, Inc. nor the names of its
**       contributors may be used to endorse or promote products derived from this
**       software without specific prior written permission.
**
**     THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
**     ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
**     WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
**     DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
**     ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
**     (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
**     LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
**     ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
**     (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
**     SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**
**     http:                 www.freescale.com
**     mail:                 support@freescale.com
**
** ###################################################################
*/
 
/* Entry Point */
ENTRY(Reset_Handler)
 
HEAP_SIZE  = DEFINED(__heap_size__)  ? __heap_size__  : 0x0400;
STACK_SIZE = DEFINED(__stack_size__) ? __stack_size__ : 0x0400;
M_VECTOR_RAM_SIZE = DEFINED(__ram_vector_table__) ? 0x0400 : 0x0;
ASSERT( (HEAP_SIZE & 0xF) == 0, "HEAP_SIZE must be multiple of 16")
ASSERT( (STACK_SIZE & 0xF) == 0, "STACK_SIZE must be multiple of 16")
 
 
/*
   MK64FN1xxxx12 on-chip SRAM is split into SRAM_L and SRAM_U regions,
   where the SRAM_L and SRAM_U ranges form a contiguous block in the
   memory map anchored at address 0x2000_0000. The two partitions are:
   - SRAM_L is anchored to 0x1FFF_FFFF and occupies 64kb *ending* at address.
   - SRAM_U is anchored to 0x2000_0000 and occupies 192kb *starting* at this address.
   NOTE: Misaligned accesses across the 0x2000_0000 boundary are not
   supported in the ARM Cortex-M4 architecture.
   DRN: This is why memory is split into m_data and m_data_2 below.   
*/
 
/* Specify the memory areas */
MEMORY
{
  m_interrupts          (RX)  : ORIGIN = 0x00000000, LENGTH = 0x00000400
  m_flash_config        (RX)  : ORIGIN = 0x00000400, LENGTH = 0x00000010
  m_text                (RX)  : ORIGIN = 0x00000410, LENGTH = 0x000FBBF0 /* was LENGTH = 0x000FFBF0 */
  /* For XXX2 we reserve the top 16kb of flash for configuration data: x000FC000–x000FFFFF */
  m_XXX2_config         (R)   : ORIGIN = 0x000FC000, LENGTH = 0x00004000
  /* bss overflowed m_data until FreeRTOS heap moved to m_data_2 */
  m_data                (RW)  : ORIGIN = 0x1FFF0000, LENGTH = 0x00010000
  m_data_2              (RW)  : ORIGIN = 0x20000000, LENGTH = 0x00030000
}
 
/* Define output sections */
SECTIONS
{
  /* The startup code goes first into internal flash */
  .interrupts :
  {
    __VECTOR_TABLE = .;
    . = ALIGN(4);
    KEEP(*(.isr_vector))     /* Startup code */
    . = ALIGN(4);
  } > m_interrupts
 
  .flash_config :
  {
    . = ALIGN(4);
    KEEP(*(.FlashConfig))    /* Flash Configuration Field (FCF) */
    . = ALIGN(4);
  } > m_flash_config
 
  /* The program code and other data goes into internal flash */
  .text :
  {
    . = ALIGN(4);
    *(.text)                 /* .text sections (code) */
    *(.text*)                /* .text* sections (code) */
    *(.rodata)               /* .rodata sections (constants, strings, etc.) */
    *(.rodata*)              /* .rodata* sections (constants, strings, etc.) */
    *(.glue_7)               /* glue arm to thumb code */
    *(.glue_7t)              /* glue thumb to arm code */
    *(.eh_frame)
    KEEP (*(.init))
    KEEP (*(.fini))
    . = ALIGN(4);
  } > m_text
 
  .ARM.extab :
  {
    *(.ARM.extab* .gnu.linkonce.armextab.*)
  } > m_text
 
  .ARM :
  {
    __exidx_start = .;
    *(.ARM.exidx*)
    __exidx_end = .;
  } > m_text
 
 .ctors :
  {
    __CTOR_LIST__ = .;
    /* gcc uses crtbegin.o to find the start of
       the constructors, so we make sure it is
       first.  Because this is a wildcard, it
       doesn't matter if the user does not
       actually link against crtbegin.o; the
       linker won't look for a file to match a
       wildcard.  The wildcard also means that it
       doesn't matter which directory crtbegin.o
       is in.  */
    KEEP (*crtbegin.o(.ctors))
    KEEP (*crtbegin?.o(.ctors))
    /* We don't want to include the .ctor section from
       from the crtend.o file until after the sorted ctors.
       The .ctor section from the crtend file contains the
       end of ctors marker and it must be last */
    KEEP (*(EXCLUDE_FILE(*crtend?.o *crtend.o) .ctors))
    KEEP (*(SORT(.ctors.*)))
    KEEP (*(.ctors))
    __CTOR_END__ = .;
  } > m_text
 
  .dtors :
  {
    __DTOR_LIST__ = .;
    KEEP (*crtbegin.o(.dtors))
    KEEP (*crtbegin?.o(.dtors))
    KEEP (*(EXCLUDE_FILE(*crtend?.o *crtend.o) .dtors))
    KEEP (*(SORT(.dtors.*)))
    KEEP (*(.dtors))
    __DTOR_END__ = .;
  } > m_text
 
  .preinit_array :
  {
    PROVIDE_HIDDEN (__preinit_array_start = .);
    KEEP (*(.preinit_array*))
    PROVIDE_HIDDEN (__preinit_array_end = .);
  } > m_text
 
  .init_array :
  {
    PROVIDE_HIDDEN (__init_array_start = .);
    KEEP (*(SORT(.init_array.*)))
    KEEP (*(.init_array*))
    PROVIDE_HIDDEN (__init_array_end = .);
  } > m_text
 
  .fini_array :
  {
    PROVIDE_HIDDEN (__fini_array_start = .);
    KEEP (*(SORT(.fini_array.*)))
    KEEP (*(.fini_array*))
    PROVIDE_HIDDEN (__fini_array_end = .);
  } > m_text
 
  __etext = .;    /* define a global symbol at end of code.  DRN: Marks beginning of copy of initialized data */
  __DATA_ROM = .; /* Symbol is used by startup for data initialization.  DRN: No, while more readable symbol, actually __etext is used...*/
 
  .interrupts_ram :
  {
    . = ALIGN(4);
    __VECTOR_RAM__ = .;
    __interrupts_ram_start__ = .; /* Create a global symbol at data start */
    *(.m_interrupts_ram)     /* This is a user defined section */
    . += M_VECTOR_RAM_SIZE;
    . = ALIGN(4);
    __interrupts_ram_end__ = .; /* Define a global symbol at data end */
  } > m_data
 
  __VECTOR_RAM = DEFINED(__ram_vector_table__) ? __VECTOR_RAM__ : ORIGIN(m_interrupts);
  __RAM_VECTOR_TABLE_SIZE_BYTES = DEFINED(__ram_vector_table__) ? (__interrupts_ram_end__ - __interrupts_ram_start__) : 0x0;
 
  .data : AT(__DATA_ROM)
  {
    . = ALIGN(4);
    __DATA_RAM = .;
    __data_start__ = .;      /* create a global symbol at data start */
    *(.data)                 /* .data sections */
    *(.data*)                /* .data* sections */
    KEEP(*(.jcr*))
    . = ALIGN(4);
    __data_end__ = .;        /* define a global symbol at end of initialized data in RAM */
  } > m_data
 
  __DATA_END = __DATA_ROM + (__data_end__ - __data_start__);
  text_end = ORIGIN(m_text) + LENGTH(m_text); /* end of portion of flash used for code (before data initialize copy) */
  ASSERT(__DATA_END <= text_end, "region m_text overflowed with text and data")
 
  __DRN_Unused_Flash = LENGTH(m_text) - __DATA_END;
  __DRN_Percent_Flash_Reserved_and_Unused = ( 100 * __DRN_Unused_Flash ) / LENGTH(m_text);
 
  __DRN_Unused_LowRam = __data_end__ - ORIGIN(m_data);
 
  XXX2_config_flash_start  = ORIGIN(m_XXX2_config); /* DRN: define base address symbol for XXX2's reserved flash area for configuration data */
  _XXX2_config_flash_length = LENGTH(m_XXX2_config); /* DRN: define length symbol for XXX2's reserved flash area for configuration data */
   
  /* Uninitialized data section */
  .bss :
  {
    /* This is used by the startup in order to initialize the .bss section */
    . = ALIGN(4);
    __START_BSS = .;
    __bss_start__ = .;
    *(.bss)
    *(.bss*)
 
    /* consolidated USB structures DRN 0622; corrected from Freescale... */
    . = ALIGN(512); /* This can waste a LOT of RAM, up to 511 bytes; better if BSS on boundary (or place USB stuff in separate memory)... */
    *(m_usb_bdt)
    *(m_usb_global)
    /* No: . += USB_RAM_GAP; */
 
    *(COMMON)
    . = ALIGN(4);
    DRN_magic_bootloader_signal_word = .; /* we don't care where this is placed for no-bootloader build */
    . += 4;
    __bss_end__ = .;
    __END_BSS = .;
    __bss_size = ABSOLUTE(. - __START_BSS);
  } > m_data_2 /* DRN: moved to m_data_2 after BSS overflowed m_data with FFT arrays */
 
  /* Place stack at top of block - this is the initial stack used before FreeRTOS starts (and by scheduler, ISRs) */
  __StackTop   = ORIGIN(m_data_2) + LENGTH(m_data_2);
  __StackLimit = __StackTop - STACK_SIZE;
  .stack __StackLimit : /* mostly to ensure no overlapping sections... */
  {
    . = ALIGN(8);
    . += STACK_SIZE;
    __stack = .;
  } > m_data_2
 
  /* Place heap before initial stack. This will be used by newlib malloc-family via sbrk function */
  __HeapBase = __StackLimit - HEAP_SIZE;
  .heap __HeapBase :
  {
    . = ALIGN(8);
    __end__ = .; /* Stunningly unhelpful name: Actually marks heap base(??), not BSS end, required only by rdimon-crt0.o (for semihosting) */
    __HeapBaseCheck = .;
    . += HEAP_SIZE;
    __HeapLimit = .;
  } > m_data_2
  ASSERT(__HeapBase == __HeapBaseCheck, "Heap alignment error")
 
  __DRN_Used_HighRam = (STACK_SIZE + HEAP_SIZE + __bss_size);
  __DRN_Unused_HighRam = LENGTH(m_data_2) - __DRN_Used_HighRam;
  /* 20170630 XXX2 debug:     0x00030000  - (0x800     0x18000 + 0x00011be4) = 5C1C (23,580 decimal bytes) */
 
  .ARM.attributes 0 : { *(.ARM.attributes) }
}