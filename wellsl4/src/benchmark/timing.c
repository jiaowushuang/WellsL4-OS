#ifdef CONFIG_EXECUTION_BENCHMARKING

#include <state/statedata.h>
#include <benchmark/timing.h>
#include <kernel/time.h>


#ifdef CONFIG_NRF_RTC_TIMER
#include <nrfx.h>

/* To get _current_thread count of timer, first 1 need to be written into
 * Capture Register and Current Count will be copied into corresponding
 * _current_thread count register.
 */
#define TIMING_INFO_PRE_READ()        (NRF_TIMER2->TASKS_CAPTURE[0] = 1)
#define TIMING_INFO_OS_GET_TIME()     (NRF_TIMER2->CC[0])
#define TIMING_INFO_GET_TIMER_VALUE() (TIMING_INFO_OS_GET_TIME())
#define SUBTRACT_CLOCCYCLES(val)    (val)

#elif CONFIG_X86
#define TIMING_INFO_PRE_READ()
#define TIMING_INFO_OS_GET_TIME()      (tsc_read())
#define TIMING_INFO_GET_TIMER_VALUE()  (TIMING_INFO_OS_GET_TIME())
#define SUBTRACT_CLOCCYCLES(val)     (val)

#elif CONFIG_ARM64
#define TIMING_INFO_PRE_READ()
#define TIMING_INFO_OS_GET_TIME()      (get_cycle_32())
#define TIMING_INFO_GET_TIMER_VALUE()  (get_cycle_32())
#define SUBTRACT_CLOCCYCLES(val)     ((u32_t)val)

#elif CONFIG_ARM
#include <arch/arm/aarch32/cortex_m/cmsis.h>
#define TIMING_INFO_PRE_READ()
#define TIMING_INFO_OS_GET_TIME()      (get_cycle_32())
#define TIMING_INFO_GET_TIMER_VALUE()  (SysTick->VAL)
#define SUBTRACT_CLOCCYCLES(val)     (SysTick->LOAD - (u32_t)val)

#elif CONFIG_ARC
#define TIMING_INFO_PRE_READ()
#define TIMING_INFO_OS_GET_TIME()     (get_cycle_32())
#define TIMING_INFO_GET_TIMER_VALUE() (arc_v2_aux_reg_read(_ARC_V2_TMR0_COUNT))
#define SUBTRACT_CLOCCYCLES(val)    ((u32_t)val)

#elif CONFIG_NIOS2
#include "altera_avalon_timer_regs.h"
#define TIMING_INFO_PRE_READ()         \
	(IOWR_ALTERA_AVALON_TIMER_SNAPL(TIMER_0_BASE, 10))

#define TIMING_INFO_OS_GET_TIME()      (SUBTRACT_CLOCCYCLES(\
	((u32_t)IORD_ALTERA_AVALON_TIMER_SNAPH(TIMER_0_BASE) << 16)\
	| ((u32_t)IORD_ALTERA_AVALON_TIMER_SNAPL(TIMER_0_BASE))))

#define TIMING_INFO_GET_TIMER_VALUE()  (\
	((u32_t)IORD_ALTERA_AVALON_TIMER_SNAPH(TIMER_0_BASE) << 16)\
	| ((u32_t)IORD_ALTERA_AVALON_TIMER_SNAPL(TIMER_0_BASE)))

#define SUBTRACT_CLOCCYCLES(val)     \
	((IORD_ALTERA_AVALON_TIMER_PERIODH(TIMER_0_BASE)	\
	  << 16 |						\
	  (IORD_ALTERA_AVALON_TIMER_PERIODL(TIMER_0_BASE)))	\
	 - ((u32_t)val))

#else
#define TIMING_INFO_PRE_READ()
#define TIMING_INFO_OS_GET_TIME()      (get_cycle_32())
#define TIMING_INFO_GET_TIMER_VALUE()  (get_cycle_32())
#define SUBTRACT_CLOCCYCLES(val)     ((u32_t)val)
#endif	/* CONFIG_NRF_RTC_TIMER */


void read_timer_start_of_swap(void)
{
	if (arch_timing_value_swap_end == 1U)
	{
		TIMING_INFO_PRE_READ();
		arch_timing_swap_start = (u32_t) TIMING_INFO_OS_GET_TIME();
	}
}

void read_timer_end_of_swap(void)
{
	if (arch_timing_value_swap_end == 1U)
	{
		TIMING_INFO_PRE_READ();
		arch_timing_value_swap_end = 2U;
		arch_timing_value_swap_common =
			(u64_t)TIMING_INFO_OS_GET_TIME();
	}
}

/* ARM processors read _current_thread value of time through sysTick timer
 * and nrf soc read it though timer
 */
void read_timer_start_of_isr(void)
{
	TIMING_INFO_PRE_READ();
	arch_timing_irq_start  = (u32_t) TIMING_INFO_GET_TIMER_VALUE();
}

void read_timer_end_of_isr(void)
{
	TIMING_INFO_PRE_READ();
	arch_timing_irq_end  = (u32_t) TIMING_INFO_GET_TIMER_VALUE();
}

void read_timer_start_of_tick_handler(void)
{
	TIMING_INFO_PRE_READ();
	arch_timing_tick_start  = (u32_t)TIMING_INFO_GET_TIMER_VALUE();
}

void read_timer_end_of_tick_handler(void)
{
	TIMING_INFO_PRE_READ();
	 arch_timing_tick_end  = (u32_t) TIMING_INFO_GET_TIMER_VALUE();
}

void read_timer_end_of_userspace_enter(void)
{
	TIMING_INFO_PRE_READ();
	arch_timing_enter_user_mode_end = (u32_t)TIMING_INFO_GET_TIMER_VALUE();
}

#endif
