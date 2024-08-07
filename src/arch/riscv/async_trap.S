.macro SAVE_REGS, from_user
    addi    sp, sp, -{trapframe_size}
    PUSH_GENERAL_REGS
    
    STR     x0, sp, 35                   // tf.ctx_type == 0

    csrr    t0, sepc
    csrr    t1, sstatus
    csrrw   t2, sscratch, zero          // save sscratch (sp) and zero it
    STR     t0, sp, 31                  // tf.sepc
    STR     t1, sp, 32                  // tf.sstatus
    STR     t2, sp, 1                   // tf.regs.sp
    .short  0xa622                      // fsd fs0,264(sp)
    .short  0xaa26                      // fsd fs1,272(sp)
.if \from_user == 1

    li      t0, 1
    STR     t0, sp, 35                   // tf.ctx_type == 1

    LDR     t1, sp, 2                   // load user gp with CPU ID
    LDR     t0, sp, 3                   // load supervisor tp
    STR     gp, sp, 2                   // save user gp and tp
    STR     tp, sp, 3
    mv      gp, t1
    mv      tp, t0
.endif
.endm

.macro RESTORE_REGS, from_user
.if \from_user == 1
    LDR     t1, sp, 2
    LDR     t0, sp, 3
    STR     gp, sp, 2                   // load user gp and tp
    STR     tp, sp, 3                   // save supervisor tp
    mv      gp, t1
    mv      tp, t0
    addi    t0, sp, {trapframe_size}    // put supervisor sp to scratch
    csrw    sscratch, t0
.endif

    LDR     t0, sp, 31
    LDR     t1, sp, 32
    csrw    sepc, t0
    csrw    sstatus, t1
    .short  0x2432                      // fld fs0,264(sp)
    .short  0x24d2                      // fld fs1,272(sp)
    POP_GENERAL_REGS
    LDR     sp, sp, 1                   // load sp from tf.regs.sp
.endm

.section .text
.balign 4
.global trap_vector_base
trap_vector_base:
    // sscratch == 0: trap from S mode
    // sscratch != 0: trap from U mode
    csrrw   sp, sscratch, sp            // switch sscratch and sp
    bnez    sp, .Ltrap_entry_u

    csrr    sp, sscratch                // put supervisor sp back
    j       .Ltrap_entry_s

.Ltrap_entry_s:
    SAVE_REGS 0
    mv      a0, sp
    li      a1, 0
    call    riscv_trap_handler
    RESTORE_REGS 0
    sret

.Ltrap_entry_u:
    # csrr    sp, sscratch                // put supervisor sp back
    SAVE_REGS 1
    mv      a0, sp
    li      a1, 1
    call    riscv_trap_handler
    RESTORE_REGS 1
    sret
