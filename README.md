# FreeRTOS Helpers
We see lots of vendors, application developers, and a few consultants Pontificating and Spewing about how solid their tools and applications are, citing MISRA-compliance and other bullox. If they would shut up for a moment and glance downwards, they'd notice they are wearing no pants and standing in quicksand, in the middle of a swamp surrounded by crocodiles...

**If you're using FreeRTOS and GCC, I hope the tools in this repository can help you create a stable platform for your applications using FreeRTOS**, at least a bit... After all, as my wife sometimes reminds it is better to wear pants, and really best to avoid standing in quicksand amidst crocodiles.

## Thoughts about FreeRTOS
We've delivered many successful applications using FreeRTOS (more than a dozen for sure but truly I've lost count). This on MCUs like PIC24F, PIC32MX, TI MSP430, and ARM Cortex from M0 through M7 from Freescale, NXP, Silicon Labs, etc. FreeRTOS supports a number of compilers, though here we use mostly GCC. We are forever in debt to Richard Barry for his most excellent efforts (and glad I was able to help a bit with the Cortex-M0 port). So, what's not to like?

FreeRTOS provides a truly excellent OS, with pretty much all the features you need for non-trivial applications on MCUs (single-core, anyway). What **FreeRTOS does NOT provide** is integration with the MCU vendor toolchains; that's left to the MCU vendors. Most importantly for typical embedded applications, FreeRTOS does not provide:
* device drivers (ethernet, serial, USB, etc.)
* USB Stack
* low-level memory management (sbrk level for many toolchains)
* integration with C-RTL (FreeRTOS assumes a working C toolchain)
* LwIP (recently documented on FreeRTOS site as more performant than FreeRTOS TCP/IP)

As the vendor-provided bits are usually crap, it can often take more time/money to create a working basic platform  than the actual target application. Not a great state of affairs. And as the complexity of the MCU peripherals (and required drivers) continues to increase, the situation worsens.

## We Support FreeRTOS! Yeah! Woo Hoo!

Well, so the MCU vendors loudly lie. The reality is horrendous. If you actually need to build an application that is both performant and reliable, the stuff provided by MCU vendors is often completely unworkable. Typical fuckups include:
* Memory management is completely broken. Your application will crash or behave mysteriously and corrupt memory when you try to use sprintf, dtoa, strtok, or other commonly-utilitized C-RTL functions. See the Heap_useNewlib section below for a solution to this one (especially if you're trying to use ST MCUs).
* drivers do not use FreeRTOS facilities. For performance and interrupt latency, we expect and **require** minimal code in ISRs moving data to/from higher layers via RTOS facilities (see https://www.freertos.org/deferred_interrupt_processing.html for a great explanation). Instead we see crap code like:  
-- ST: Incomplete, buggy, and horrendously coded USB stack executed almost entirely within ISR, even using malloc inside ISR! Incomplete USB functionality, inadequate performance, and hugely excessive interrupt latency. As an added bonus, drops USB packets under load.  
-- ST: Buggy ethernet drivers: Missing required memory barriers, not properly coded for context-safety (ie race conditions between ISR code and foreground code).  
-- ST: Improper LwIP integration  
-- ST: Crypto hardware, but no drivers integrated into TCP/IP to support HTTPS etc.  
-- Microchip: buggy drivers polled in a single timer-based thread not properly integrated with FreeRTOS. You probably won't notice this if you try to use Microchip's Harmony framework, as most likely the output of their 'configuration wizard' won't even compile!  
-- Silicon Labs: USB driver incomplete, buggy, and not integrated with FreeRTOS.

I could go on but it gives me a headache. Again, the consequence of this sad state of affairs is it often costs more time/money to get a working and performant platform than to create your actual application. You get to rewrite and stress-test drivers and their RTOS integration for your chosen peripherals, and after that maybe you can develop your application...

# Safe memory management: heap_useNewlib
[GNU ARM Embedded Toolchain distributions](https://developer.arm.com/open-source/gnu-toolchain/gnu-rm) include a non-polluting reduced-size runtime library called newlib (or newlib-nano for the smallest variant). If you use an MCU-vendor-distributed toolchain you're typically using these tools. Unfortunately, newlib internally uses free storage (malloc/free) in startling places within the C runtime library. Thus, newlib free storage routines get dragged in and used unexpectedly. And some MCU vendors don't properly support newlib use within FreeRTOS. So your application will crash or behave mysteriously and corrupt memory when you try to use sprintf, dtoa, strtok, or other commonly-utilitized C-RTL functions. Please see my web pages for details about the problem and how to use the solution (code) provided in this repository:
* [NXP MCUXpresso users](http://www.nadler.com/embedded/NXP_newlibAndFreeRTOS.html)
* [ST RubeMX users](http://www.nadler.com/embedded/NXP_newlibAndFreeRTOS.html)
* Other MCUs and toolchains: start with the NXP version

# FreeRTOS ISR Stack Check (for Arm Cortex M4-7)
On ARM, FreeRTOS ISRs run on the dedicated MSP stack, typically allocated at top of RAM. This is great, as you don't need to reserve stack space for the deepest nested ISR stack-use for each task as older processors. While FreeRTOS provides great tools for checking actual stack use for tasks, it does not provide any means for checking actual MSP stack use by your ISRs. port_DRN.C adds code to check MSP stack use. Exclude FreeRTOS amazon-freertos/freertos_kernel/portable/GCC/ARM_CM4F/port.c from your build and add port_DRN.C, then configure your MSP stack size and enable MSP checking by adding to your FreeRTOSconfig.h:

    // DRN ISR (MSP) stack initialization and checking
    #define configISR_STACK_SIZE_WORDS (0x100) // in WORDS, must be valid constant for GCC assembler
    #define configSUPPORT_ISR_STACK_CHECK  1   // DRN initialize and check ISR stack
    UBaseType_t xUnusedISRstackWords( void );  // check unused amount at runtime
