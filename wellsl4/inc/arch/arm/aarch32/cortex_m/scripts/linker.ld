/*
 * Copyright (c) 2013-2014 Wind River Systems, Inc.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * @file
 * @brief Linker command/script file
 *
 * Linker script for the Cortex-M platforms.
 */

#include <autoconf.h>
#include <generated_dts_board.h>
#include <linker/sections.h>


#include <linker/linker_defs.h>
#include <linker/linker-tool.h>


/* physical address of RAM */
#ifdef CONFIG_XIP
#define ROMABLE_REGION FLASH
#define RAMABLE_REGION SRAM
#else
#define ROMABLE_REGION SRAM
#define RAMABLE_REGION SRAM
#endif

#if defined(CONFIG_XIP)
#define _DATA_IN_ROM __data_rom_start
#else
#define _DATA_IN_ROM
#endif

#if !defined(CONFIG_XIP) && (CONFIG_FLASH_SIZE == 0)
#define ROM_ADDR RAM_ADDR
#else
#define ROM_ADDR (CONFIG_FLASH_BASE_ADDRESS + CONFIG_FLASH_LOAD_OFFSET)
#endif

#ifdef CONFIG_HAS_TI_CCFG
#define CCFG_SIZE 88
#define ROM_SIZE (CONFIG_FLASH_SIZE*1K - CONFIG_FLASH_LOAD_OFFSET - \
	CCFG_SIZE)
#define CCFG_ADDR (ROM_ADDR + ROM_SIZE)
#else
#if CONFIG_FLASH_LOAD_SIZE > 0
#define ROM_SIZE CONFIG_FLASH_LOAD_SIZE
#else
#define ROM_SIZE (CONFIG_FLASH_SIZE*1K - CONFIG_FLASH_LOAD_OFFSET)
#endif
#endif

#if defined(CONFIG_XIP)
#if defined(CONFIG_IS_BOOTLOADER)
#define RAM_SIZE (CONFIG_BOOTLOADER_SRAM_SIZE * 1K)
#define RAM_ADDR (CONFIG_SRAM_BASE_ADDRESS + \
	(CONFIG_SRAM_SIZE * 1K - RAM_SIZE))
#else
#define RAM_SIZE (CONFIG_SRAM_SIZE * 1K)
#define RAM_ADDR CONFIG_SRAM_BASE_ADDRESS
#endif
#else
#define RAM_SIZE (CONFIG_SRAM_SIZE * 1K - CONFIG_BOOTLOADER_SRAM_SIZE * 1K)
#define RAM_ADDR CONFIG_SRAM_BASE_ADDRESS
#endif

#if defined(CONFIG_CUSTOM_SECTION_ALIGN)
_region_min_align = CONFIG_CUSTOM_SECTION_MIN_ALIGN_SIZE;
#else
/* Set alignment to CONFIG_ARM_MPU_REGION_MIN_ALIGN_AND_SIZE
 * to make linker section alignment comply with MPU granularity.
 */
#if defined(CONFIG_ARM_MPU_REGION_MIN_ALIGN_AND_SIZE)
_region_min_align = CONFIG_ARM_MPU_REGION_MIN_ALIGN_AND_SIZE;
#else
/* If building without MPU support, use default 4-byte alignment. */
_region_min_align = 4;
#endif
#endif

#if !defined(CONFIG_CUSTOM_SECTION_ALIGN) && defined(CONFIG_MPU_REQUIRES_POWER_OF_TWO_ALIGNMENT)
#define MPU_ALIGN(region_size) \
    . = ALIGN(_region_min_align); \
    . = ALIGN( 1 << LOG2CEIL(region_size))
#else
#define MPU_ALIGN(region_size) \
    . = ALIGN(_region_min_align)
#endif

MEMORY
    {
    FLASH                 (rx) : ORIGIN = ROM_ADDR, LENGTH = ROM_SIZE
#ifdef CONFIG_HAS_TI_CCFG
    FLASH_CCFG            (rwx): ORIGIN = CCFG_ADDR, LENGTH = CCFG_SIZE
#endif
#ifdef DT_CCM_BASE_ADDRESS
    CCM                   (rw) : ORIGIN = DT_CCM_BASE_ADDRESS, LENGTH = DT_CCM_SIZE * 1K
#endif
#ifdef DT_DTCM_BASE_ADDRESS
    DTCM                  (rw) : ORIGIN = DT_DTCM_BASE_ADDRESS, LENGTH = DT_DTCM_SIZE * 1K
#endif
    SRAM                  (wx) : ORIGIN = RAM_ADDR, LENGTH = RAM_SIZE
#ifdef CONFIG_BT_STM32_IPM
    SRAM1                 (rw) : ORIGIN = RAM1_ADDR, LENGTH = RAM1_SIZE
    SRAM2                 (rw) : ORIGIN = RAM2_ADDR, LENGTH = RAM2_SIZE
#endif
    /* Used by and documented in include/linker/intlist.ld */
    IDT_LIST  (wx)      : ORIGIN = (RAM_ADDR + RAM_SIZE), LENGTH = 2K
    }

ENTRY(CONFIG_KERNEL_ENTRY)

SECTIONS
    {

#include <linker/rel-sections.ld>

    /*
     * .plt and .iplt are here according to 'arm-wellsl4-elf-ld --verbose',
     * before text section.
     */
    /DISCARD/ :
	{
	*(.plt)
	}

    /DISCARD/ :
	{
	*(.iplt)
	}

    GROUP_START(ROMABLE_REGION)

	_image_rom_start = ROM_ADDR;

    SECTION_PROLOGUE(text_start,,)
	{

/* Located in generated directory. This file is populated by calling
 * wellsl4_linker_sources(ROM_START ...). This typically contains the vector
 * table and debug information.
 */
#include <snippets-text-start.ld>

	} GROUP_LINK_IN(ROMABLE_REGION)

#ifdef CONFIG_CODE_DATA_RELOCATION

#include <linker_relocate.ld>

#endif /* CONFIG_CODE_DATA_RELOCATION */

    SECTION_PROLOGUE(_TEXT_SECTION_NAME,,)
	{
	_image_text_start = .;

#include <linker/priv_stacks-text.ld>
/* #include <linker/kobject-text.ld> */

	*(.text)
	*(".text.*")
	*(.gnu.linkonce.t.*)

	/*
	 * These are here according to 'arm-wellsl4-elf-ld --verbose',
	 * after .gnu.linkonce.t.*
	 */
	*(.glue_7t) *(.glue_7) *(.vfp11_veneer) *(.v4_bx)

	} GROUP_LINK_IN(ROMABLE_REGION)

	_image_text_end = .;

#if defined (CONFIG_CPLUSPLUS)
	SECTION_PROLOGUE(.ARM.extab,,)
	{
	/*
	 * .ARM.extab section containing exception unwinding information.
	 */
	*(.ARM.extab* .gnu.linkonce.armextab.*)
	} GROUP_LINK_IN(ROMABLE_REGION)
#endif

	SECTION_PROLOGUE(.ARM.exidx,,)
	{
	/*
	 * This section, related to stack and exception unwinding, is placed
	 * explicitly to prevent it from being shared between multiple regions.
	 * It  must be defined for gcc to support 64-bit math and avoid
	 * section overlap.
	 */
	__exidx_start = .;
#if defined (__GCC_LINKER_CMD__)
	*(.ARM.exidx* gnu.linkonce.armexidx.*)
#endif
	__exidx_end = .;
	} GROUP_LINK_IN(ROMABLE_REGION)

	_image_rodata_start = .;

#include <linker/common-rom.ld>

    SECTION_PROLOGUE(_RODATA_SECTION_NAME,,)
	{
	*(.rodata)
	*(".rodata.*")
	*(.gnu.linkonce.r.*)

/* Located in generated directory. This file is populated by the
 * wellsl4_linker_sources() Cmake function.
 */
#include <snippets-rodata.ld>
#ifdef CONFIG_SOC_RODATA_LD
#include <soc-rodata.ld>
#endif

#ifdef CONFIG_CUSTOM_RODATA_LD
/* Located in project source directory */
#include <custom-rodata.ld>
#endif

#include <linker/priv_stacks-rom.ld>
/* #include <linker/kobject-rom.ld> */

	/*
	 * For XIP images, in order to avoid the situation when __data_rom_start
	 * is 32-bit aligned, but the actual data is placed right after rodata
	 * section, which may not end exactly at 32-bit border, pad rodata
	 * section, so __data_rom_start points at data and it is 32-bit aligned.
	 *
	 * On non-XIP images this may enlarge image size up to 3 bytes. This
	 * generally is not an issue, since modern ROM and FLASH memory is
	 * usually 4k aligned.
	 */
	. = ALIGN(4);
	} GROUP_LINK_IN(ROMABLE_REGION)

#include <linker/cplusplus-rom.ld>

	_image_rodata_end = .;
	MPU_ALIGN(_image_rodata_end -_image_rom_start);
	_image_rom_end = .;

    GROUP_END(ROMABLE_REGION)

/* Some TI SoCs have a special configuration footer, at the end of flash. */
#ifdef CONFIG_HAS_TI_CCFG
    SECTION_PROLOGUE(.ti_ccfg,,)
    {
    KEEP(*(TI_CCFG))
    } > FLASH_CCFG
#endif

    /*
     * These are here according to 'arm-wellsl4-elf-ld --verbose',
     * before data section.
     */
    /DISCARD/ : {
	*(.got.plt)
	*(.igot.plt)
	*(.got)
	*(.igot)
	}

    GROUP_START(RAMABLE_REGION)

	. = RAM_ADDR;
	/* Align the start of image SRAM with the
	 * minimum granularity required by MPU.
	 */
	. = ALIGN(_region_min_align);
	_image_ram_start = .;

#if defined(CONFIG_SOC_SERIES_STM32F0X) && !defined(CONFIG_IS_BOOTLOADER)
    /* Must be first in ramable region */
	SECTION_PROLOGUE(.st_stm32f0x_vt,(NOLOAD),)
	{
        _ram_vector_start = .;
        . += _vector_end - _vector_start;
        _ram_vector_end = .;
	} GROUP_DATA_LINK_IN(RAMABLE_REGION, RAMABLE_REGION)
#endif

/* Located in generated directory. This file is populated by the
 * wellsl4_linker_sources() Cmake function.
 */
#include <snippets-ram-sections.ld>

#if defined(CONFIG_USERSPACE)
#define APP_SHARED_ALIGN . = ALIGN(_region_min_align);
#define SMEM_PARTITION_ALIGN MPU_ALIGN

#include <app_smem.ld>

	_app_smem_size = _app_smem_end - _app_smem_start;
	_app_smem_rom_start = LOADADDR(_APP_SMEM_SECTION_NAME);
#endif  /* CONFIG_USERSPACE */

    SECTION_DATA_PROLOGUE(_BSS_SECTION_NAME,(NOLOAD),)
	{
        /*
         * For performance, BSS section is assumed to be 4 byte aligned and
         * a multiple of 4 bytes
         */
        . = ALIGN(4);
	__bss_start = .;
	__kernel_ram_start = .;

	*(.bss)
	*(".bss.*")
	*(COMMON)
	*(".kernel_bss.*")

#ifdef CONFIG_CODE_DATA_RELOCATION
#include <linker_sram_bss_relocate.ld>
#endif

        /*
         * As memory is cleared in words only, it is simpler to ensure the BSS
         * section ends on a 4 byte boundary. This wastes a maximum of 3 bytes.
		 */
	__bss_end = ALIGN(4);
	} GROUP_DATA_LINK_IN(RAMABLE_REGION, RAMABLE_REGION)

    SECTION_PROLOGUE(_NOINIT_SECTION_NAME,(NOLOAD),)
        {
        /*
         * This section is used for non-initialized objects that
         * will not be cleared during the boot process.
         */
        *(.noinit)
        *(".noinit.*")
	*(".kernel_noinit.*")

/* Located in generated directory. This file is populated by the
 * wellsl4_linker_sources() Cmake function.
 */
#include <snippets-noinit.ld>
#ifdef CONFIG_SOC_NOINIT_LD
#include <soc-noinit.ld>
#endif

        } GROUP_LINK_IN(RAMABLE_REGION)

    SECTION_DATA_PROLOGUE(_DATA_SECTION_NAME,,)
	{
	__data_ram_start = .;
	*(.data)
	*(".data.*")
	*(".kernel.*")

/* Located in generated directory. This file is populated by the
 * wellsl4_linker_sources() Cmake function.
 */
#include <snippets-rwdata.ld>
#ifdef CONFIG_SOC_RWDATA_LD
#include <soc-rwdata.ld>
#endif

#ifdef CONFIG_CUSTOM_RWDATA_LD
/* Located in project source directory */
#include <custom-rwdata.ld>
#endif

#ifdef CONFIG_CODE_DATA_RELOCATION
#include <linker_sram_data_relocate.ld>
#endif

	} GROUP_DATA_LINK_IN(RAMABLE_REGION, ROMABLE_REGION)

    __data_rom_start = LOADADDR(_DATA_SECTION_NAME);

#include <linker/common-ram.ld>
#include <linker/priv_stacks.ld>
/* #include <linker/kobject.ld> */

#include <linker/priv_stacks-noinit.ld>
#include <linker/cplusplus-ram.ld>

    __data_ram_end = .;


    /* Define linker symbols */

    _image_ram_end = .;
    _end = .; /* end of image */

    __kernel_ram_end = RAM_ADDR + RAM_SIZE;
    __kernel_ram_size = __kernel_ram_end - __kernel_ram_start;

    GROUP_END(RAMABLE_REGION)

#ifdef DT_DTCM_BASE_ADDRESS
GROUP_START(DTCM)

	SECTION_PROLOGUE(_DTCM_BSS_SECTION_NAME, (NOLOAD),SUBALIGN(4))
	{
		__dtcm_start = .;
		__dtcm_bss_start = .;
		*(.dtcm_bss)
		*(".dtcm_bss.*")
	} GROUP_LINK_IN(DTCM)

	__dtcm_bss_end = .;

	SECTION_PROLOGUE(_DTCM_NOINIT_SECTION_NAME, (NOLOAD),SUBALIGN(4))
	{
		__dtcm_noinit_start = .;
		*(.dtcm_noinit)
		*(".dtcm_noinit.*")
	} GROUP_LINK_IN(DTCM)

	__dtcm_noinit_end = .;

	SECTION_PROLOGUE(_DTCM_DATA_SECTION_NAME,,SUBALIGN(4))
	{
		__dtcm_data_start = .;
		*(.dtcm_data)
		*(".dtcm_data.*")
	} GROUP_LINK_IN(DTCM AT> ROMABLE_REGION)

	__dtcm_data_end = .;
	__dtcm_end = .;

	__dtcm_data_rom_start = LOADADDR(_DTCM_DATA_SECTION_NAME);

GROUP_END(DTCM)
#endif /* DT_DTCM_BASE_ADDRESS */
#ifdef CONFIG_CUSTOM_SECTIONS_LD
/* Located in project source directory */
#include <custom-sections.ld>
#endif

/* Located in generated directory. This file is populated by the
 * wellsl4_linker_sources() Cmake function.
 */
#include <snippets-sections.ld>

#include <linker/debug-sections.ld>

    /DISCARD/ : { *(.note.GNU-stack) }

    SECTION_PROLOGUE(.ARM.attributes, 0,)
	{
	KEEP(*(.ARM.attributes))
	KEEP(*(.gnu.attributes))
	}

/* Must be last in romable region */
SECTION_PROLOGUE(.last_section,(NOLOAD),)
{
} GROUP_LINK_IN(ROMABLE_REGION)

/* To provide the image size as a const expression,
 * calculate this value here. */
_flash_used = LOADADDR(.last_section) - _image_rom_start;

    }
