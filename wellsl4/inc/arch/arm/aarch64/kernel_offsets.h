/*
 * Copyright (c) 2019 Carlo Caione <ccaione@baylibre.com>
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef ARCH_ARM_INCLUDE_AARCH64_OFFSETS_SHORT_ARCH_H_
#define ARCH_ARM_INCLUDE_AARCH64_OFFSETS_SHORT_ARCH_H_

#include <offsets.h>

#define _thread_offset_to_swap_return_value \
	(__ktcb_t_arch_OFFSET + __thread_arch_t_swap_return_value_OFFSET)

#endif /* ARCH_ARM_INCLUDE_AARCH64_OFFSETS_SHORT_ARCH_H_ */
