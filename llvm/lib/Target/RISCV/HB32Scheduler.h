//===-- HB32Scheduler.h - HB32 Subtarget specific passes ----------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// HB32 Vanilla Core specific passes.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_RISCV_HB32SCHEDULER_H
#define LLVM_LIB_TARGET_RISCV_HB32SCHEDULER_H

#include "llvm/CodeGen/MachineScheduler.h"

namespace llvm {

/// Creates HB32 single-issue Scheduler. This creates a custom scheduler in
/// place of default scheduler if corresponding flag is provided on the command
/// line.
ScheduleDAGInstrs *createHB32Scheduler(MachineSchedContext *C);

/// Creates HB32 dual-issue Scheduler. This creates a custom scheduler in
/// place of default scheduler if corresponding flag is provided on the command
/// line.
ScheduleDAGInstrs *createHB32DualScheduler(MachineSchedContext *C);

/// Custom scheduler for HB32 single-issue Vanilla Core extending the generic
/// scheduler. Only overrides pickNode for remote load prioritization.
class HB32Scheduler : public GenericScheduler {
public:
  HB32Scheduler(const MachineSchedContext *C) : GenericScheduler(C) {}

protected:
  SUnit *pickNode(bool &IsTopNode) override;
};

/// Custom scheduler for HB32 dual-issue Vanilla Core extending the generic
/// scheduler. Adds slot tracking in front of FUs and dual-issue pairing logic.
/// Shwet TODO: deprecate single-issue once changes are approved and heavily tested.
class HB32DualScheduler : public GenericScheduler {

  enum Slot { None, Int, FP };

  unsigned IntSlotIdx = 0;
  unsigned FPSlotIdx = 0;
  Slot LastSchedSlot = None;

  Slot getSlot(SUnit *SU) const;

public:
  HB32DualScheduler(const MachineSchedContext *C) : GenericScheduler(C) {}
  void initialize(ScheduleDAGMI *dag) override;
  SUnit *pickNode(bool &IsTopNode) override;
  void schedNode(SUnit *SU, bool IsTopNode) override;
};

} // end namespace llvm

#endif // LLVM_LIB_TARGET_RISCV_HB32SCHEDULER_H