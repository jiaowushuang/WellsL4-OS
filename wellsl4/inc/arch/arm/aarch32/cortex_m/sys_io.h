/*
 * Copyright (c) 2015, Wind River Systems, Inc.
 * Copyright (c) 2017, Oticon A/S
 *
 * SPDX-License-Identifier: Apache-2.0
 */

/* "Arch" bit manipulation functions in non-arch-specific C code (uses some
 * gcc builtins)
 */

#ifndef ARCH_COMMON_SYS_IO_H_
#define ARCH_COMMON_SYS_IO_H_

#ifndef _ASMLANGUAGE


#ifdef __cplusplus
extern "C" {
#endif

static FORCE_INLINE byte_t sys_read8(maddr_t addr)
{
	return *(volatile byte_t *)addr;
}

static FORCE_INLINE void sys_write8(byte_t data, maddr_t addr)
{
	*(volatile byte_t *)addr = data;
}

static FORCE_INLINE u16_t sys_read16(maddr_t addr)
{
	return *(volatile u16_t *)addr;
}

static FORCE_INLINE void sys_write16(u16_t data, maddr_t addr)
{
	*(volatile u16_t *)addr = data;
}

static FORCE_INLINE u32_t sys_read32(maddr_t addr)
{
	return *(volatile u32_t *)addr;
}

static FORCE_INLINE void sys_write32(u32_t data, maddr_t addr)
{
	*(volatile u32_t *)addr = data;
}

/* Memory bit manipulation functions */

static FORCE_INLINE void sys_set_bit(maddr_t addr, word_t bit)
{
	u32_t temp = *(volatile u32_t *)addr;

	*(volatile u32_t *)addr = temp | (1 << bit);
}

static FORCE_INLINE void sys_clear_bit(maddr_t addr, word_t bit)
{
	u32_t temp = *(volatile u32_t *)addr;

	*(volatile u32_t *)addr = temp & ~(1 << bit);
}

static FORCE_INLINE sword_t sys_test_bit(maddr_t addr, word_t bit)
{
	u32_t temp = *(volatile u32_t *)addr;

	return temp & (1 << bit);
}

/* << 2 equal to 2^2 = 4 bytes = 32 bit = >> 5 */
static FORCE_INLINE
	void sys_bitfield_set_bit(maddr_t addr, word_t bit)
{
	/* Doing memory offsets in terms of 32-bit values to prevent
	 * alignment issues
	 */
	sys_set_bit(addr + ((bit >> 5) << 2), bit & 0x1F);
}

static FORCE_INLINE
	void sys_bitfield_clear_bit(maddr_t addr, word_t bit)
{
	sys_clear_bit(addr + ((bit >> 5) << 2), bit & 0x1F);
}

static FORCE_INLINE
	sword_t sys_bitfield_test_bit(maddr_t addr, word_t bit)
{
	return sys_test_bit(addr + ((bit >> 5) << 2), bit & 0x1F);
}

static FORCE_INLINE
	sword_t sys_test_and_set_bit(maddr_t addr, word_t bit)
{
	sword_t ret;

	ret = sys_test_bit(addr, bit);
	sys_set_bit(addr, bit);

	return ret;
}

static FORCE_INLINE
	sword_t sys_test_and_clear_bit(maddr_t addr, word_t bit)
{
	sword_t ret;

	ret = sys_test_bit(addr, bit);
	sys_clear_bit(addr, bit);

	return ret;
}

static FORCE_INLINE
	sword_t sys_bitfield_test_and_set_bit(maddr_t addr, word_t bit)
{
	sword_t ret;

	ret = sys_bitfield_test_bit(addr, bit);
	sys_bitfield_set_bit(addr, bit);

	return ret;
}

static FORCE_INLINE
	sword_t sys_bitfield_test_and_clear_bit(maddr_t addr, word_t bit)
{
	sword_t ret;

	ret = sys_bitfield_test_bit(addr, bit);
	sys_bitfield_clear_bit(addr, bit);

	return ret;
}

#ifdef __cplusplus
}
#endif

#endif

#endif
