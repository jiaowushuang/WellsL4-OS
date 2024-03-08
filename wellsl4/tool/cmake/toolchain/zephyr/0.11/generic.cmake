# SPDX-License-Identifier: Apache-2.0

set(TOOLCHAIN_HOME ${WELLSL4_SDK_INSTALL_DIR})

set(COMPILER gcc)
set(LINKER ld)
set(BINTOOLS gnu)

set(CROSS_COMPILE_TARGET x86_64-${TOOLCHAIN_VENDOR}-elf)
set(SYSROOT_TARGET       x86_64-${TOOLCHAIN_VENDOR}-elf)

set(CROSS_COMPILE ${TOOLCHAIN_HOME}/${CROSS_COMPILE_TARGET}/bin/${CROSS_COMPILE_TARGET}-)
set(SYSROOT_DIR ${WELLSL4_SDK_INSTALL_DIR}/sysroots/${SYSROOT_TARGET}/usr)
set(TOOLCHAIN_HAS_NEWLIB ON CACHE BOOL "True if toolchain supports newlib")
