#include <toolchain.h>
#include <linker/sections.h>
#include <kernel_offsets.h>
#include <api/syscall.h>
#include <syscall_list.h>

_ASM_FILE_PROLOGUE

GTEXT(arm_userspace_enter)
GTEXT(arm_do_syscall)
GTEXT(arch_user_string_nlen)
GTEXT(arm_user_string_nlen_fault_start)
GTEXT(arm_user_string_nlen_fault_end)
GTEXT(arm_user_string_nlen_fixup)
GDATA(_kernel)

/* Imports */
GDATA(k_syscall_table)

/**
 *
 * User space entry function
 *
 * This function is the entry point to user mode from privileged execution.
 * The conversion is one way, and threads which transition to user mode do
 * not transition back later, unless they are doing system calls.
 *
 * The function is invoked as:
 * arm_userspace_enter(user_entry, p1, p2, p3,
 *                        stack_info.start, stack_info.size);
 */
SECTION_FUNC(TEXT,arm_userspace_enter)
    /* move user_entry to lr */
    mov lr, r0

#if defined(CONFIG_BUILTIN_STACK_GUARD)
    /* clear stack pointer limit before setting the PSP */
    mov r0, #0
    msr PSPLIM, r0
#endif

    /* prepare to set stack to privileged stack */
    ldr r0, =_kernel
    ldr r0, [r0, #_kernel_offset_to_current]
#if defined(CONFIG_ARMV6_M_ARMV8_M_BASELINE)
    /* move p1 to ip */
    mov ip, r1
    ldr r1, =_thread_offset_to_priv_stack_start
    ldr r0, [r0, r1]    /* priv stack ptr */
    ldr r1, =CONFIG_PRIVILEGED_STACK_SIZE
    add r0, r0, r1
    /* Restore p1 from ip */
    mov r1, ip
#elif defined(CONFIG_ARMV7_M_ARMV8_M_MAINLINE)
    ldr r0, [r0, #_thread_offset_to_priv_stack_start]    /* priv stack ptr */
    ldr ip, =CONFIG_PRIVILEGED_STACK_SIZE
    add r0, r0, ip
#endif

    /* store current stack pointer to ip
     * the current stack pointer is needed to retrieve
     * stack_info.start and stack_info.size
     */
    mov ip, sp

    /* set stack to privileged stack */
    msr PSP, r0

#if defined(CONFIG_BUILTIN_STACK_GUARD)
    /* set stack pointer limit to the start of the priv stack */
    ldr r0, =_kernel
    ldr r0, [r0, #_kernel_offset_to_current]
    ldr r0, [r0, #_thread_offset_to_priv_stack_start]    /* priv stack ptr */
    msr PSPLIM, r0
#endif

    /* push args to stack */
    push {r1,r2,r3,lr}
#if defined(CONFIG_ARMV6_M_ARMV8_M_BASELINE)
    mov r1, ip
    push {r0,r1}
#elif defined(CONFIG_ARMV7_M_ARMV8_M_MAINLINE)
    push {r0,ip}
#endif

    /* Re-program dynamic memory map.
     *
     * Important note:
     * arm_configure_dynamic_mpu_regions() may re-program the MPU Stack Guard
     * to guard the privilege stack for overflows (if building with option
     * CONFIG_MPU_STACK_GUARD). There is a risk of actually overflowing the
     * stack while doing the re-programming. We minimize the risk by placing
     * this function immediately after we have switched to the privileged stack
     * so that the whole stack area is available for this critical operation.
     *
     * Note that the risk for overflow is higher if using the normal thread
     * stack, since we do not control how much stack is actually left, when
     * user invokes arm_userspace_enter().
     */
    ldr r0, =_kernel
    ldr r0, [r0, #_kernel_offset_to_current]
    bl arm_configure_dynamic_mpu_regions

#if defined(CONFIG_ARMV6_M_ARMV8_M_BASELINE)
    pop {r0,r3}

    /* load up stack info from user stack */
    ldr r0, [r3]
    ldr r3, [r3, #4]
    mov ip, r3

    push {r0,r3}
#elif defined(CONFIG_ARMV7_M_ARMV8_M_MAINLINE)
    pop {r0,ip}

    /* load up stack info from user stack */
    ldr r0, [ip]
    ldr ip, [ip, #4]

    push {r0,ip}
#endif

    /* clear the user stack area to clean out privileged data */
    /* from right past the guard right up to the end */
    mov r2, ip
#ifdef CONFIG_INIT_STACKS
    ldr r1,=0xaaaaaaaa
#else
    eors.n r1, r1
#endif
    bl memset

#if defined(CONFIG_ARMV6_M_ARMV8_M_BASELINE)
    pop {r0, r1}
    mov ip, r1
#elif (defined(CONFIG_ARMV7_M_ARMV8_M_MAINLINE))
    pop {r0,ip}
#endif

    /* r0 contains user stack start, ip contains user stack size */
    add r0, r0, ip   /* calculate top of stack */

#if defined(CONFIG_BUILTIN_STACK_GUARD)
    /* clear stack limit (stack protection not required in user mode) */
    mov r3, #0
    msr PSPLIM, r3
#endif

    /* pop remaining arguments from stack before switching stacks */
#if defined(CONFIG_ARMV6_M_ARMV8_M_BASELINE)
    /* Use r4 to pop lr, then restore r4 */
    mov ip, r4
    pop {r1,r2,r3,r4}
    mov lr, r4
    mov r4, ip
#elif defined(CONFIG_ARMV7_M_ARMV8_M_MAINLINE)
    pop {r1,r2,r3,lr}
#endif

    /* set stack to user stack */
    msr PSP, r0

    /* restore r0 */
    mov r0, lr

#ifdef CONFIG_EXECUTION_BENCHMARKING
    stm sp!,{r0-r3} /* Save regs r0 to r4 on stack */
    push {r0, lr}
    bl read_timer_end_of_userspace_enter
#if defined(CONFIG_ARMV6_M_ARMV8_M_BASELINE)
    pop {r0, r3}
    mov lr,r3
#else
    pop {r0, lr}
#endif /* CONFIG_ARMV6_M_ARMV8_M_BASELINE */
    ldm sp!,{r0-r3} /* Restore r0 to r3 regs */

#endif /* CONFIG_EXECUTION_BENCHMARKING */

    /* change processor mode to unprivileged */
#if defined(CONFIG_ARMV6_M_ARMV8_M_BASELINE)
    push {r0, r1, r2, r3}
    ldr r0, =_kernel
    ldr r0, [r0, #_kernel_offset_to_current]
    ldr r1, =_thread_offset_to_mode
    ldr r1, [r0, r1]
    movs r2, #1
    orrs r1, r1, r2
    mrs r3, CONTROL
    orrs r3, r3, r2
    mov ip, r3
    /* Store (unprivileged) mode in thread's mode state variable */
    ldr r2, =_thread_offset_to_mode
    str r1, [r0, r2]
#elif defined(CONFIG_ARMV7_M_ARMV8_M_MAINLINE)
    push {r0, r1}
    ldr r0, =_kernel
    ldr r0, [r0, #_kernel_offset_to_current]
    ldr r1, [r0, #_thread_offset_to_mode]
    orrs r1, r1, #1
    mrs ip, CONTROL
    orrs ip, ip, #1
    /* Store (unprivileged) mode in thread's mode state variable */
    str r1, [r0, #_thread_offset_to_mode]
#endif
    dsb
    msr CONTROL, ip

    /* ISB is not strictly necessary here (stack pointer is not being
     * touched), but it's recommended to avoid executing pre-fetched
     * instructions with the previous privilege.
     */
    isb
#if defined(CONFIG_ARMV6_M_ARMV8_M_BASELINE)
    pop {r0, r1, r2, r3}
#elif defined(CONFIG_ARMV7_M_ARMV8_M_MAINLINE)
    pop {r0, r1}
#endif

    /* jump to thread_entry_point entry */
#if defined(CONFIG_ARMV6_M_ARMV8_M_BASELINE)
    push {r0, r1}
    ldr r0, =thread_entry_point
    mov ip, r0
    pop {r0, r1}
#elif defined(CONFIG_ARMV7_M_ARMV8_M_MAINLINE)
    ldr ip, =thread_entry_point
#endif
    bx ip

/**
 *
 * Userspace system call function
 *
 * This function is used to do system calls from unprivileged code.  This
 * function is responsible for the following:
 * 1) Fixing up bad syscalls
 * 2) Configuring privileged stack and loading up stack arguments
 * 3) Dispatching the system call
 * 4) Restoring stack and calling back to the caller of the SVC
 *
 */
SECTION_FUNC(TEXT, arm_do_syscall)

    /* The function is executing in privileged mode. This implies that we
     * shall not be allowed to use the thread's default unprivileged stack,
     * (i.e push to or pop from it), to avoid a possible stack corruption.
     *
     * Rationale: since we execute in PRIV mode and no MPU guard or PSPLIM
     * register is guarding the end of the default stack, we won't be able
     * to detect any stack overflows.
     */

#if defined(CONFIG_BUILTIN_STACK_GUARD)
    /* clear stack pointer limit before setting the PSP */
    mov ip, #0
    msr PSPLIM, ip
#endif

#if defined(CONFIG_ARMV6_M_ARMV8_M_BASELINE)
    /* save current stack pointer (user stack) */
    mov ip, sp
    /* temporarily push to user stack */
    push {r0,r1}
    /* setup privileged stack */
    ldr r0, =_kernel
    ldr r0, [r0, #_kernel_offset_to_current]
    adds r0, r0, #_thread_offset_to_priv_stack_start
    ldr r0, [r0]    /* priv stack ptr */
    ldr r1, =CONFIG_PRIVILEGED_STACK_SIZE
    add r0, r1

    /* Store current SP and LR at the beginning of the priv stack */
    subs r0, #8
    mov r1, ip
    str r1, [r0, #0]
    mov r1, lr
    str r1, [r0, #4]
    mov ip, r0
    /* Restore user stack and original r0, r1 */
    pop {r0, r1}

#elif defined(CONFIG_ARMV7_M_ARMV8_M_MAINLINE)
    /* setup privileged stack */
    ldr ip, =_kernel
    ldr ip, [ip, #_kernel_offset_to_current]
    ldr ip, [ip, #_thread_offset_to_priv_stack_start]    /* priv stack ptr */
    add ip, #CONFIG_PRIVILEGED_STACK_SIZE

    /* Store current SP and LR at the beginning of the priv stack */
    subs ip, #8
    str sp, [ip, #0]
    str lr, [ip, #4]
#endif

    /* switch to privileged stack */
    msr PSP, ip

#if defined(CONFIG_BUILTIN_STACK_GUARD)
    /* Set stack pointer limit (needed in privileged mode) */
    ldr ip, =_kernel
    ldr ip, [ip, #_kernel_offset_to_current]
    ldr ip, [ip, #_thread_offset_to_priv_stack_start]    /* priv stack ptr */
    msr PSPLIM, ip
#endif

    /*
     * r0-r5 contain arguments
     * r6 contains call_id
     * r8 contains original LR
     */
#if defined(CONFIG_ARMV6_M_ARMV8_M_BASELINE)
    /* save  r0, r1 to ip, lr */
    mov ip, r0
    mov lr, r1
    ldr r0, =K_SYSCALL_INVAILD
    cmp r6, r0
    bne valid_syscall

    /* BAD SYSCALL path */
    /* fixup stack frame on the privileged stack, adding ssf */
    mov r1, sp
    push {r4,r5}
    /* ssf is present in r1 (sp) */
    push {r1,lr}
    /* restore r0, r1 */
    mov r0, ip
    mov r1, lr
    b dispatch_syscall
valid_syscall:
    /* push args to complete stack frame */
    push {r4,r5}

dispatch_syscall:
    /* original r0 is saved in ip */
    ldr r0, =k_syscall_table
    lsls r6, #2
    add r0, r6
    ldr r0, [r0]	/* load table address */
    /* swap ip and r0, restore r1 from lr */
    mov r1, ip
    mov ip, r0
    mov r0, r1
    mov r1, lr
    /* execute function from dispatch table */
    blx ip

    /* restore LR
     * r0 holds the return value and needs to be preserved
     */
    mov ip, r0
    mov r0, sp
    adds r0, #12
    ldr r0, [r0]
    mov lr, r0
    /* Restore r0 */
    mov r0, ip

#elif defined(CONFIG_ARMV7_M_ARMV8_M_MAINLINE)
    ldr ip, =K_SYSCALL_INVAILD
    cmp r6, ip
    bne valid_syscall

    /* BAD SYSCALL path */
    /* fixup stack frame on the privileged stack, adding ssf */
    mov ip, sp
    push {r4,r5,ip,lr}
    b dispatch_syscall

valid_syscall:
    /* push args to complete stack frame */
    push {r4,r5}

dispatch_syscall:
    ldr ip, =k_syscall_table
    lsl r6, #2
    add ip, r6
    ldr ip, [ip]	/* load table address */
    /* execute function from dispatch table */
    blx ip

    /* restore LR */
    ldr lr, [sp,#12]
#endif

#if defined(CONFIG_BUILTIN_STACK_GUARD)
    /* clear stack limit (stack protection not required in user mode) */
    mov r3, #0
    msr PSPLIM, r3
#endif

#if defined(CONFIG_ARMV6_M_ARMV8_M_BASELINE)
    /* set stack back to unprivileged stack */
    mov ip, r0
    mov r0, sp
    ldr r0, [r0,#8]
    msr PSP, r0
    /* Restore r0 */
    mov r0, ip

#elif defined(CONFIG_ARMV7_M_ARMV8_M_MAINLINE)
    /* set stack back to unprivileged stack */
    ldr ip, [sp,#8]
    msr PSP, ip
#endif

    push {r0, r1}
#if defined(CONFIG_ARMV6_M_ARMV8_M_BASELINE)
    push {r2, r3}
    ldr r0, =_kernel
    ldr r0, [r0, #_kernel_offset_to_current]
    ldr r2, =_thread_offset_to_mode
    ldr r1, [r0, r2]
    movs r3, #1
    orrs r1, r1, r3
    /* Store (unprivileged) mode in thread's mode state variable */
    str r1, [r0, r2]
    dsb
    /* drop privileges by setting bit 0 in CONTROL */
    mrs r2, CONTROL
    orrs r2, r2, r3
    msr CONTROL, r2
    pop {r2, r3}
#elif defined(CONFIG_ARMV7_M_ARMV8_M_MAINLINE)
    ldr r0, =_kernel
    ldr r0, [r0, #_kernel_offset_to_current]
    ldr r1, [r0, #_thread_offset_to_mode]
    orrs r1, r1, #1
    /* Store (unprivileged) mode in thread's mode state variable */
    str r1, [r0, #_thread_offset_to_mode]
    dsb
    /* drop privileges by setting bit 0 in CONTROL */
    mrs ip, CONTROL
    orrs ip, ip, #1
    msr CONTROL, ip
#endif

    /* ISB is not strictly necessary here (stack pointer is not being
     * touched), but it's recommended to avoid executing pre-fetched
     * instructions with the previous privilege.
     */
    isb
    pop {r0, r1}

#if defined(CONFIG_ARMV6_M_ARMV8_M_BASELINE)
  /* Zero out volatile (caller-saved) registers so as to not leak state from
   * kernel mode. The C calling convention for the syscall handler will
   * restore the others to original values.
   */
   movs r2, #0
   movs r3, #0

   /*
    * return back to original function that called SVC, add 1 to force thumb
    * mode
    */

    /* Save return value temporarily to ip */
    mov ip, r0

    mov r0, r8
    movs r1, #1
    orrs r0, r0, r1

    /* swap ip, r0 */
    mov r1, ip
    mov ip, r0
    mov r0, r1
    movs r1, #0
#elif defined(CONFIG_ARMV7_M_ARMV8_M_MAINLINE)

    /* Zero out volatile (caller-saved) registers so as to not leak state from
     * kernel mode. The C calling convention for the syscall handler will
     * restore the others to original values.
     */
    mov r1, #0
    mov r2, #0
    mov r3, #0

    /*
     * return back to original function that called SVC, add 1 to force thumb
     * mode
     */
    mov ip, r8
    orrs ip, ip, #1

#endif
    bx ip


/*
 * size_t arch_user_string_nlen(const char *s, size_t maxsize, int *err_arg)
 */
SECTION_FUNC(TEXT, arch_user_string_nlen)
    push {r0, r1, r2, r4, r5, lr}

    /* sp+4 is error value, init to -1 */
#if defined(CONFIG_ARMV6_M_ARMV8_M_BASELINE)
    ldr r3, =-1
#elif defined(CONFIG_ARMV7_M_ARMV8_M_MAINLINE)
    mov.w r3, #-1
#endif
    str	r3, [sp, #4]

    /* Perform string length calculation */
    movs r3, #0		/* r3 is the counter */

strlen_loop:
arm_user_string_nlen_fault_start:
    /* r0 contains the string. r5 = *(r0 + r3]). This could fault. */
    ldrb r5, [r0, r3]

arm_user_string_nlen_fault_end:
#if defined(CONFIG_ARMV6_M_ARMV8_M_BASELINE)
    cmp r5, #0
    beq strlen_done
#elif defined(CONFIG_ARMV7_M_ARMV8_M_MAINLINE)
    cbz	r5, strlen_done
#endif
    cmp	r3, r1
    beq.n strlen_done

    adds r3, #1
    b.n	strlen_loop

strlen_done:
    /* Move length calculation from r3 to r0 (return value register) */
    mov	r0, r3

    /* Clear error value since we succeeded */
    movs r1, #0
    str	r1, [sp, #4]

arm_user_string_nlen_fixup:
    /* Write error value to err pointer parameter */
    ldr	r1, [sp, #4]
    str	r1, [r2, #0]

    add	sp, #12
    pop	{r4, r5, pc}

