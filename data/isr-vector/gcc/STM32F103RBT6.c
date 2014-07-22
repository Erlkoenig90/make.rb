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
void WWDG_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void PVD_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TAMPER_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void RTC_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void FLASH_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void RCC_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void EXTI0_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void EXTI1_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void EXTI2_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void EXTI3_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void EXTI4_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA1_Channel1_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA1_Channel2_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA1_Channel3_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA1_Channel4_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA1_Channel5_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA1_Channel6_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA1_Channel7_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void ADC1_2_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void USB_HP_CAN1_TX_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void USB_LP_CAN1_RX0_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void CAN1_RX1_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void CAN1_SCE_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void EXTI9_5_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIM1_BRK_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIM1_UP_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIM1_TRG_COM_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIM1_CC_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIM2_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIM3_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIM4_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void I2C1_EV_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void I2C1_ER_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void I2C2_EV_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void I2C2_ER_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void SPI1_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void SPI2_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void USART1_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void USART2_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void USART3_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void EXTI15_10_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void RTCAlarm_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void USBWakeUp_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
extern uint32_t _estack __attribute__((weak));
uint32_t isr_vector [] __attribute__ ((used, section (".isr_vector"))) = {(uint32_t) &_estack,
(uint32_t) &Reset_Handler,(uint32_t) &NMI_Handler,(uint32_t) &HardFault_Handler,(uint32_t) &MemManage_Handler,(uint32_t) &BusFault_Handler,(uint32_t) &UsageFault_Handler,0,0,0,0,(uint32_t) &SVCall_Handler,(uint32_t) &DebugMon_Handler,0,(uint32_t) &PendSV_Handler,(uint32_t) &SysTick_Handler,(uint32_t) &WWDG_IRQHandler,(uint32_t) &PVD_IRQHandler,(uint32_t) &TAMPER_IRQHandler,(uint32_t) &RTC_IRQHandler,(uint32_t) &FLASH_IRQHandler,(uint32_t) &RCC_IRQHandler,(uint32_t) &EXTI0_IRQHandler,(uint32_t) &EXTI1_IRQHandler,(uint32_t) &EXTI2_IRQHandler,(uint32_t) &EXTI3_IRQHandler,(uint32_t) &EXTI4_IRQHandler,(uint32_t) &DMA1_Channel1_IRQHandler,(uint32_t) &DMA1_Channel2_IRQHandler,(uint32_t) &DMA1_Channel3_IRQHandler,(uint32_t) &DMA1_Channel4_IRQHandler,(uint32_t) &DMA1_Channel5_IRQHandler,(uint32_t) &DMA1_Channel6_IRQHandler,(uint32_t) &DMA1_Channel7_IRQHandler,(uint32_t) &ADC1_2_IRQHandler,(uint32_t) &USB_HP_CAN1_TX_IRQHandler,(uint32_t) &USB_LP_CAN1_RX0_IRQHandler,(uint32_t) &CAN1_RX1_IRQHandler,(uint32_t) &CAN1_SCE_IRQHandler,(uint32_t) &EXTI9_5_IRQHandler,(uint32_t) &TIM1_BRK_IRQHandler,(uint32_t) &TIM1_UP_IRQHandler,(uint32_t) &TIM1_TRG_COM_IRQHandler,(uint32_t) &TIM1_CC_IRQHandler,(uint32_t) &TIM2_IRQHandler,(uint32_t) &TIM3_IRQHandler,(uint32_t) &TIM4_IRQHandler,(uint32_t) &I2C1_EV_IRQHandler,(uint32_t) &I2C1_ER_IRQHandler,(uint32_t) &I2C2_EV_IRQHandler,(uint32_t) &I2C2_ER_IRQHandler,(uint32_t) &SPI1_IRQHandler,(uint32_t) &SPI2_IRQHandler,(uint32_t) &USART1_IRQHandler,(uint32_t) &USART2_IRQHandler,(uint32_t) &USART3_IRQHandler,(uint32_t) &EXTI15_10_IRQHandler,(uint32_t) &RTCAlarm_IRQHandler,(uint32_t) &USBWakeUp_IRQHandler,};
#ifdef __cplusplus
	}
#endif

