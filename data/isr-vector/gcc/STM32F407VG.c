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
void TAMP_STAMP_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void RTC_WKUP_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void FLASH_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void RCC_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void EXTI0_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void EXTI1_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void EXTI2_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void EXTI3_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void EXTI4_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA1_Stream0_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA1_Stream1_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA1_Stream2_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA1_Stream3_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA1_Stream4_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA1_Stream5_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA1_Stream6_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void ADC_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void CAN0_TX_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void CAN0_RX0_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void CAN0_RX1_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void CAN0_SCE_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void EXTI9_5_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIM0_BRK_TIM8_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIM0_UP_TIM9_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIM0_TRG_COM_TIM10_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIM0_CC_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIM1_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIM2_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIM3_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
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
void RTC_Alarm_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void OTG_FS_WKUP_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIM7_BRK_TIM11_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIM7_UP_TIM12_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIM7_TRG_COM_TIM13_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIM7_CC_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA1_Stream7_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void FSMC_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void SDIO_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIM4_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void SPI3_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void UART4_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void UART5_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIM5_DAC_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void TIM6_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA2_Stream0_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA2_Stream1_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA2_Stream2_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA2_Stream3_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA2_Stream4_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void ETH_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void ETH_WKUP_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void CAN1_TX_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void CAN1_RX0_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void CAN1_RX1_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void CAN1_SCE_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void OTG_FS_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA2_Stream5_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA2_Stream6_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DMA2_Stream7_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void USART6_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void I2C3_EV_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void I2C3_ER_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void OTG_HS_EP1_OUT_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void OTG_HS_EP1_IN_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void OTG_HS_WKUP_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void OTG_HS_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void DCMI_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void CRYP_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void HASH_RNG_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
void FPU_IRQHandler ()  __attribute__ ((weak, used, alias ("Default_Handler")));
extern uint32_t _estack __attribute__((weak));
uint32_t isr_vector [] __attribute__ ((used, section (".isr_vector"))) = {(uint32_t) &_estack,
(uint32_t) &Reset_Handler,(uint32_t) &NMI_Handler,(uint32_t) &HardFault_Handler,(uint32_t) &MemManage_Handler,(uint32_t) &BusFault_Handler,(uint32_t) &UsageFault_Handler,0,0,0,0,(uint32_t) &SVCall_Handler,(uint32_t) &DebugMon_Handler,0,(uint32_t) &PendSV_Handler,(uint32_t) &SysTick_Handler,(uint32_t) &WWDG_IRQHandler,(uint32_t) &PVD_IRQHandler,(uint32_t) &TAMP_STAMP_IRQHandler,(uint32_t) &RTC_WKUP_IRQHandler,(uint32_t) &FLASH_IRQHandler,(uint32_t) &RCC_IRQHandler,(uint32_t) &EXTI0_IRQHandler,(uint32_t) &EXTI1_IRQHandler,(uint32_t) &EXTI2_IRQHandler,(uint32_t) &EXTI3_IRQHandler,(uint32_t) &EXTI4_IRQHandler,(uint32_t) &DMA1_Stream0_IRQHandler,(uint32_t) &DMA1_Stream1_IRQHandler,(uint32_t) &DMA1_Stream2_IRQHandler,(uint32_t) &DMA1_Stream3_IRQHandler,(uint32_t) &DMA1_Stream4_IRQHandler,(uint32_t) &DMA1_Stream5_IRQHandler,(uint32_t) &DMA1_Stream6_IRQHandler,(uint32_t) &ADC_IRQHandler,(uint32_t) &CAN0_TX_IRQHandler,(uint32_t) &CAN0_RX0_IRQHandler,(uint32_t) &CAN0_RX1_IRQHandler,(uint32_t) &CAN0_SCE_IRQHandler,(uint32_t) &EXTI9_5_IRQHandler,(uint32_t) &TIM0_BRK_TIM8_IRQHandler,(uint32_t) &TIM0_UP_TIM9_IRQHandler,(uint32_t) &TIM0_TRG_COM_TIM10_IRQHandler,(uint32_t) &TIM0_CC_IRQHandler,(uint32_t) &TIM1_IRQHandler,(uint32_t) &TIM2_IRQHandler,(uint32_t) &TIM3_IRQHandler,(uint32_t) &I2C1_EV_IRQHandler,(uint32_t) &I2C1_ER_IRQHandler,(uint32_t) &I2C2_EV_IRQHandler,(uint32_t) &I2C2_ER_IRQHandler,(uint32_t) &SPI1_IRQHandler,(uint32_t) &SPI2_IRQHandler,(uint32_t) &USART1_IRQHandler,(uint32_t) &USART2_IRQHandler,(uint32_t) &USART3_IRQHandler,(uint32_t) &EXTI15_10_IRQHandler,(uint32_t) &RTC_Alarm_IRQHandler,(uint32_t) &OTG_FS_WKUP_IRQHandler,(uint32_t) &TIM7_BRK_TIM11_IRQHandler,(uint32_t) &TIM7_UP_TIM12_IRQHandler,(uint32_t) &TIM7_TRG_COM_TIM13_IRQHandler,(uint32_t) &TIM7_CC_IRQHandler,(uint32_t) &DMA1_Stream7_IRQHandler,(uint32_t) &FSMC_IRQHandler,(uint32_t) &SDIO_IRQHandler,(uint32_t) &TIM4_IRQHandler,(uint32_t) &SPI3_IRQHandler,(uint32_t) &UART4_IRQHandler,(uint32_t) &UART5_IRQHandler,(uint32_t) &TIM5_DAC_IRQHandler,(uint32_t) &TIM6_IRQHandler,(uint32_t) &DMA2_Stream0_IRQHandler,(uint32_t) &DMA2_Stream1_IRQHandler,(uint32_t) &DMA2_Stream2_IRQHandler,(uint32_t) &DMA2_Stream3_IRQHandler,(uint32_t) &DMA2_Stream4_IRQHandler,(uint32_t) &ETH_IRQHandler,(uint32_t) &ETH_WKUP_IRQHandler,(uint32_t) &CAN1_TX_IRQHandler,(uint32_t) &CAN1_RX0_IRQHandler,(uint32_t) &CAN1_RX1_IRQHandler,(uint32_t) &CAN1_SCE_IRQHandler,(uint32_t) &OTG_FS_IRQHandler,(uint32_t) &DMA2_Stream5_IRQHandler,(uint32_t) &DMA2_Stream6_IRQHandler,(uint32_t) &DMA2_Stream7_IRQHandler,(uint32_t) &USART6_IRQHandler,(uint32_t) &I2C3_EV_IRQHandler,(uint32_t) &I2C3_ER_IRQHandler,(uint32_t) &OTG_HS_EP1_OUT_IRQHandler,(uint32_t) &OTG_HS_EP1_IN_IRQHandler,(uint32_t) &OTG_HS_WKUP_IRQHandler,(uint32_t) &OTG_HS_IRQHandler,(uint32_t) &DCMI_IRQHandler,(uint32_t) &CRYP_IRQHandler,(uint32_t) &HASH_RNG_IRQHandler,(uint32_t) &FPU_IRQHandler,};
#ifdef __cplusplus
	}
#endif

