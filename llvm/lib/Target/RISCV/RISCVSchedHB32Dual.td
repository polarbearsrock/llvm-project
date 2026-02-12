//==- RISCVSchedHB32Dual.td - Hammerblade Dual-Issue Scheduling -*- tablegen -*-=//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

// ===---------------------------------------------------------------------===//
// The following definitions describe the simpler per-operand machine model.
// This works with MachineScheduler. See MCSchedule.h for details.

// Hammerblade dual-issue machine model for scheduling and other instruction cost heuristics.
def HB32DualModel : SchedMachineModel {
  let MicroOpBufferSize = 0; // Explicitly set to zero since HB is in-order.
  let IssueWidth = 2;        // 2 micro-ops can be issued per cycle.
  let LoadLatency = 2;
  let MispredictPenalty = 2; // IF + ID squashed
  let CompleteModel = 0;     //TODO(Shwet): All instructions have been covered.
}

//===----------------------------------------------------------------------===//
// Define each kind of processor resource and number available.

// Define issue slots for integer and FP unit for now.
// Reference TargetSchedule.td for usage of Super.
 def HB32DualIntSlot : ProcResource<1> { let BufferSize = 0; }
 def HB32DualFPSlot  : ProcResource<1> { let BufferSize = 0; }

// Modeling each pipeline as a ProcResource using the BufferSize = 0.

let BufferSize = 0 in {
def HB32DualUnitALU        : ProcResource<1> { let Super = HB32DualIntSlot; } // Int ALU
def HB32DualUnitIMul       : ProcResource<1> { let Super = HB32DualIntSlot; } // Int Multiply
def HB32DualUnitMem        : ProcResource<1> { let Super = HB32DualIntSlot; } // Load/Store
def HB32DualUnitB          : ProcResource<1> { let Super = HB32DualIntSlot; } // Branch

def HB32DualUnitFPALU      : ProcResource<1> { let Super = HB32DualFPSlot; } // FP ALU
}

let BufferSize = 1 in {
def HB32DualUnitIDiv       : ProcResource<1> { let Super = HB32DualIntSlot; } // Int Division
def HB32DualUnitFPDivSqrt  : ProcResource<1> { let Super = HB32DualFPSlot; } // FP Divide/Sqrt
}

//===----------------------------------------------------------------------===//
// Subtarget-specific SchedWrite types which both map the ProcResources and
// set the latency.

let SchedModel = HB32DualModel in {

// Branches must end the issue group as the instruction after a conditional branch
// cannot be paired.
let EndGroup = 1 in {
def : WriteRes<WriteJmp, [HB32DualUnitB]>;
def : WriteRes<WriteJal, [HB32DualUnitB]>;
def : WriteRes<WriteJalr, [HB32DualUnitB]>;
}

// ALU Ops.

def : WriteRes<WriteIALU, [HB32DualUnitALU]>;

// Shift ops. Same comment as above.
def : WriteRes<WriteShiftImm, [HB32DualUnitALU]>;
def : WriteRes<WriteShiftReg, [HB32DualUnitALU]>;

// Integer multiply unit.
def : WriteRes<WriteIMul, [HB32DualUnitIMul]> {
  let Latency = 2;
  let ReleaseAtCycles = [1];
  }

// 32-bit divides take 32+ cycles, TODO(Emily): we maybe want to determine worst case
def : WriteRes<WriteIDiv, [HB32DualUnitIDiv]> {
  let Latency = 32;
  let ReleaseAtCycles = [32];
}

def : WriteRes<WriteIRem, [HB32DualUnitIDiv]> {
  let Latency = 32;
  let ReleaseAtCycles = [32];
}

// Memory
def : WriteRes<WriteSTB, [HB32DualUnitMem]>;
def : WriteRes<WriteSTH, [HB32DualUnitMem]>;
def : WriteRes<WriteSTW, [HB32DualUnitMem]>;
def : WriteRes<WriteFST32, [HB32DualUnitMem]>;

let Latency = 1 in {
def : WriteRes<WriteCSR, [HB32DualUnitALU]>;
}

let Latency = 3 in {
  def : WriteRes<WriteFMovI32ToF32, [HB32DualUnitFPALU]>;
  def : WriteRes<WriteFLD32, [HB32DualUnitMem]>;
}

let Latency = 2 in {
  def : WriteRes<WriteLDW, [HB32DualUnitMem]>;
  def : WriteRes<WriteLDB, [HB32DualUnitMem]>;
  def : WriteRes<WriteLDH, [HB32DualUnitMem]>;

  def : WriteRes<WriteAtomicW, [HB32DualUnitMem]>;
  def : WriteRes<WriteAtomicLDW, [HB32DualUnitMem]>;
}

def : WriteRes<WriteAtomicSTW, [HB32DualUnitMem]>;

// Most FP single precision operations are 3 cycles
let Latency = 3 in {
  def : WriteRes<WriteFAdd32, [HB32DualUnitFPALU]>;
  def : WriteRes<WriteFSGNJ32, [HB32DualUnitFPALU]>;
  def : WriteRes<WriteFMinMax32, [HB32DualUnitFPALU]>;
}

let Latency = 2 in {
  def : WriteRes<WriteFCvtF32ToI32, [HB32DualUnitFPALU]>;
  def : WriteRes<WriteFClass32, [HB32DualUnitFPALU]>;
  def : WriteRes<WriteFCmp32, [HB32DualUnitFPALU]>;
  def : WriteRes<WriteFMovF32ToI32, [HB32DualUnitFPALU]>;
}

let Latency = 3 in {
def : WriteRes<WriteFCvtI32ToF32, [HB32DualUnitFPALU]>;
}

//FPU takes 4 cycles (TODO: confirm this)
let Latency = 3 in {
  def : WriteRes<WriteFMul32, [HB32DualUnitFPALU]>;
  def : WriteRes<WriteFMA32, [HB32DualUnitFPALU]>;
}

// TODO(Shwet): Verify.
def : WriteRes<WriteFDiv32, [HB32DualUnitFPDivSqrt]> {
  let Latency = 32;
  let ReleaseAtCycles = [32];
}

def : WriteRes<WriteFSqrt32, [HB32DualUnitFPDivSqrt]> {
  let Latency = 32;
  let ReleaseAtCycles = [32];
}

def : WriteRes<WriteNop, []>;

// Occupy ALU for COPY MIR instructions.
def : InstRW<[WriteIALU], (instrs COPY)>;

//TODO(Emily): need to fill out the instructions we don't support
let Unsupported = 1 in {
def : WriteRes<WriteIALU32, []>;
def : WriteRes<WriteShiftImm32, []>;
def : WriteRes<WriteShiftReg32, []>;
def : WriteRes<WriteIMul32, []>;
def : WriteRes<WriteIDiv32, []>;
def : WriteRes<WriteIRem32, []>;
def : WriteRes<WriteSTD, []>;
def : WriteRes<WriteLDD, []>;
def : WriteRes<WriteAtomicD, []>;
def : WriteRes<WriteAtomicLDD, []>;
def : WriteRes<WriteAtomicSTD, []>;
def : WriteRes<WriteFCvtI64ToF32, []>;
def : WriteRes<WriteFCvtF32ToI64, []>;
}

//===----------------------------------------------------------------------===//
// Subtarget-specific SchedRead types with cycles.
// TODO(Emily): need to determine if these are supported and their cycle counts
def : ReadAdvance<ReadJmp, 0>;
def : ReadAdvance<ReadJalr, 0>;
def : ReadAdvance<ReadCSR, 0>;
def : ReadAdvance<ReadStoreData, 0>;
def : ReadAdvance<ReadMemBase, 0>;
def : ReadAdvance<ReadIALU, 0>;
def : ReadAdvance<ReadIALU32, 0>;
def : ReadAdvance<ReadShiftImm, 0>;
def : ReadAdvance<ReadShiftReg, 0>;
def : ReadAdvance<ReadShiftImm32, 0>;
def : ReadAdvance<ReadShiftReg32, 0>;
def : ReadAdvance<ReadIDiv, 0>;
def : ReadAdvance<ReadIDiv32, 0>;
def : ReadAdvance<ReadIRem, 0>;
def : ReadAdvance<ReadIRem32, 0>;
def : ReadAdvance<ReadIMul, 0>;
def : ReadAdvance<ReadIMul32, 0>;
def : ReadAdvance<ReadAtomicWA, 0>;
def : ReadAdvance<ReadAtomicWD, 0>;
def : ReadAdvance<ReadAtomicDA, 0>;
def : ReadAdvance<ReadAtomicDD, 0>;
def : ReadAdvance<ReadAtomicLDW, 0>;
def : ReadAdvance<ReadAtomicLDD, 0>;
def : ReadAdvance<ReadAtomicSTW, 0>;
def : ReadAdvance<ReadAtomicSTD, 0>;
def : ReadAdvance<ReadFAdd32, 0>;
def : ReadAdvance<ReadFSGNJ32, 0>;
def : ReadAdvance<ReadFMinMax32, 0>;
def : ReadAdvance<ReadFMul32, 0>;
def : ReadAdvance<ReadFMA32, 0>;
def : ReadAdvance<ReadFMA32Addend, 0>;
def : ReadAdvance<ReadFDiv32, 0>;
def : ReadAdvance<ReadFSqrt32, 0>;
def : ReadAdvance<ReadFCmp32, 0>;
def : ReadAdvance<ReadFCvtF32ToI32, 0>;
def : ReadAdvance<ReadFCvtF32ToI64, 0>;
def : ReadAdvance<ReadFCvtI32ToF32, 0>;
def : ReadAdvance<ReadFCvtI64ToF32, 0>;
def : ReadAdvance<ReadFMovF32ToI32, 0>;
def : ReadAdvance<ReadFMovI32ToF32, 0>;
def : ReadAdvance<ReadFClass32, 0>;
def : ReadAdvance<ReadFStoreData, 0>;
def : ReadAdvance<ReadFMemBase, 0>;

// Unsupported extensions via multiclass.
defm : UnsupportedSchedD; // for now disabling D extension.
defm : UnsupportedSchedV;
defm : UnsupportedSchedZabha;
defm : UnsupportedSchedZba;
defm : UnsupportedSchedZbb;
defm : UnsupportedSchedZbc;
defm : UnsupportedSchedZbs;
defm : UnsupportedSchedZbkb;
defm : UnsupportedSchedZbkx;
defm : UnsupportedSchedZfa;
defm : UnsupportedSchedZfhmin;
defm : UnsupportedSchedSFB;
defm : UnsupportedSchedZvk;
defm : UnsupportedSchedXsf;
}
