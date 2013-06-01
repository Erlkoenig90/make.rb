#include <stdint.h>
extern uint32_t _sidata, _sdata, _edata, _sbss, _ebss;
extern void (*__preinit_array_start []) (void) __attribute__((weak));
extern void (*__preinit_array_end []) (void) __attribute__((weak));
extern void (*__init_array_start []) (void) __attribute__((weak));
extern void (*__init_array_end []) (void) __attribute__((weak));


extern int main (void);

void __attribute__((naked)) Reset_Handler () {
	uint32_t* target = &_sdata;
	const uint32_t* src = &_sidata;
	while (target != &_edata) {
		*target = *src;
		target++; src++;
	}
	uint32_t* ptr = &_sbss;
	while (ptr != &_ebss) {
		*ptr = 0;
		ptr++;
	}

	uint32_t count, i;

	count = __preinit_array_end - __preinit_array_start;
	for (i = 0; i < count; i++)
		__preinit_array_start[i] ();

	count = __init_array_end - __init_array_start;
	for (i = 0; i < count; i++)
		__init_array_start[i] ();

	main ();
}
