#include <stdint.h>
#ifdef __cplusplus
	extern "C" {
#endif

void Default_Handler (void) {
	asm volatile ("bkpt");
	while (1); // Read IPSR (lowest byte of xPSR) to get IRQ Number.
}
void Reset_Handler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void NMI_Handler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void HardFault_Handler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void MemManage_Handler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void BusFault_Handler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void UsageFault_Handler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void SVCall_Handler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DebugMon_Handler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void PendSV_Handler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void SysTick_Handler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void WDT_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIMER0_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIMER1_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIMER2_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIMER3_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void UART0_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void UART1_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void UART2_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void UART3_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void PWM1_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void I2C0_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void I2C1_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void I2C2_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void SPI_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void SSP0_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void SSP1_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void PLL0_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void RTC_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void EINT0_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void EINT1_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void EINT2_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void EINT3_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void ADC_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void BOD_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void USB_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void CAN_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void I2S_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void ENET_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void RIT_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void MCPWM_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void QEI_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void PLL1_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void USBActivity_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void CANActivity_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
extern uint32_t _estack __attribute__((weak));
uint32_t isr_vector [] __attribute__ ((used, section (".isr_vector"))) = {(uint32_t) &_estack,
(uint32_t) &Reset_Handler,(uint32_t) &NMI_Handler,(uint32_t) &HardFault_Handler,(uint32_t) &MemManage_Handler,(uint32_t) &BusFault_Handler,(uint32_t) &UsageFault_Handler,0,0,0,0,(uint32_t) &SVCall_Handler,(uint32_t) &DebugMon_Handler,0,(uint32_t) &PendSV_Handler,(uint32_t) &SysTick_Handler,(uint32_t) &WDT_IRQHandler,(uint32_t) &TIMER0_IRQHandler,(uint32_t) &TIMER1_IRQHandler,(uint32_t) &TIMER2_IRQHandler,(uint32_t) &TIMER3_IRQHandler,(uint32_t) &UART0_IRQHandler,(uint32_t) &UART1_IRQHandler,(uint32_t) &UART2_IRQHandler,(uint32_t) &UART3_IRQHandler,(uint32_t) &PWM1_IRQHandler,(uint32_t) &I2C0_IRQHandler,(uint32_t) &I2C1_IRQHandler,(uint32_t) &I2C2_IRQHandler,(uint32_t) &SPI_IRQHandler,(uint32_t) &SSP0_IRQHandler,(uint32_t) &SSP1_IRQHandler,(uint32_t) &PLL0_IRQHandler,(uint32_t) &RTC_IRQHandler,(uint32_t) &EINT0_IRQHandler,(uint32_t) &EINT1_IRQHandler,(uint32_t) &EINT2_IRQHandler,(uint32_t) &EINT3_IRQHandler,(uint32_t) &ADC_IRQHandler,(uint32_t) &BOD_IRQHandler,(uint32_t) &USB_IRQHandler,(uint32_t) &CAN_IRQHandler,(uint32_t) &DMA_IRQHandler,(uint32_t) &I2S_IRQHandler,(uint32_t) &ENET_IRQHandler,(uint32_t) &RIT_IRQHandler,(uint32_t) &MCPWM_IRQHandler,(uint32_t) &QEI_IRQHandler,(uint32_t) &PLL1_IRQHandler,(uint32_t) &USBActivity_IRQHandler,(uint32_t) &CANActivity_IRQHandler,};
#ifdef __cplusplus
	}
#endif

