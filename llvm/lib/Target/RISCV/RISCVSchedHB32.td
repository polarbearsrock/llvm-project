//==- RISCVSchedHB32.td - Hammerblade Scheduling Definitions -*- tablegen -*-=//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

// ===---------------------------------------------------------------------===//
// The following definitions describe the simpler per-operand machine model.
// This works with MachineScheduler. See MCSchedule.h for details.

// Hammerblade machine model for scheduling and other instruction cost heuristics.
def HB32Model : SchedMachineModel {
  let MicroOpBufferSize = 0; // Explicitly set to zero since HB is in-order.
  let IssueWidth = 2;        // 2 micro-ops can be issued per cycle.
  let LoadLatency = 2;
  let MispredictPenalty = 3; //TODO(Emily): need to determine this value
  let CompleteModel = 0;     //TODO(Shwet): All instructions have been covered.
}

//===----------------------------------------------------------------------===//
// Define each kind of processor resource and number available.

// Define issue slots for integer and FP unit for now.
// Reference TargetSchedule.td for usage of Super.
 def HB32IntSlot : ProcResource<1> { let BufferSize = 0; }                                                                                                                                                                                                                                                                 
 def HB32FPSlot  : ProcResource<1> { let BufferSize = 0; }

// Modeling each pipeline as a ProcResource using the BufferSize = 0.

let BufferSize = 0 in {
def HB32UnitALU        : ProcResource<1> { let Super = HB32IntSlot; } // Int ALU
def HB32UnitIMul       : ProcResource<1> { let Super = HB32IntSlot; } // Int Multiply
def HB32UnitMem        : ProcResource<1> { let Super = HB32IntSlot; } // Load/Store
def HB32UnitB          : ProcResource<1> { let Super = HB32IntSlot; } // Branch

def HB32UnitFPALU      : ProcResource<1> { let Super = HB32FPSlot; } // FP ALU
}

let BufferSize = 1 in {
def HB32UnitIDiv       : ProcResource<1> { let Super = HB32IntSlot; } // Int Division
def HB32UnitFPDivSqrt  : ProcResource<1> { let Super = HB32FPSlot; } // FP Divide/Sqrt
}

//===----------------------------------------------------------------------===//
// Subtarget-specific SchedWrite types which both map the ProcResources and
// set the latency.

let SchedModel = HB32Model in {

def : WriteRes<WriteJmp, [HB32UnitB]>;
def : WriteRes<WriteJal, [HB32UnitB]>;
def : WriteRes<WriteJalr, [HB32UnitB]>;

// ALU Ops.

def : WriteRes<WriteIALU, [HB32UnitALU]>;

// Shift ops. Same comment as above.
def : WriteRes<WriteShiftImm, [HB32UnitALU]>;
def : WriteRes<WriteShiftReg, [HB32UnitALU]>;

// Integer multiply unit.
def : WriteRes<WriteIMul, [HB32UnitIMul]> { 
  let Latency = 32; 
  let ReleaseAtCycles = [1];
  }

// 32-bit divides take 32+ cycles, TODO(Emily): we maybe want to determine worst case
def : WriteRes<WriteIDiv, [HB32UnitIDiv]> {
  let Latency = 32;
  let ReleaseAtCycles = [32];
}

def : WriteRes<WriteIRem, [HB32UnitIDiv]> {                                                                                                                                                                                                                                                              
  let Latency = 32;                                                                                                                                                                                                                                                                                      
  let ReleaseAtCycles = [32];                                                                                                                                                                                                                                                                            
}

// Memory
def : WriteRes<WriteSTB, [HB32UnitMem]>;
def : WriteRes<WriteSTH, [HB32UnitMem]>;
def : WriteRes<WriteSTW, [HB32UnitMem]>;
def : WriteRes<WriteFST32, [HB32UnitMem]>;

let Latency = 3 in {
def : WriteRes<WriteLDB, [HB32UnitMem]>;
def : WriteRes<WriteLDH, [HB32UnitMem]>;
def : WriteRes<WriteCSR, [HB32UnitALU]>;
}

let Latency = 2 in {
def : WriteRes<WriteLDW, [HB32UnitMem]>;
def : WriteRes<WriteFLD32, [HB32UnitMem]>;

def : WriteRes<WriteAtomicW, [HB32UnitMem]>;
def : WriteRes<WriteAtomicLDW, [HB32UnitMem]>;
}

def : WriteRes<WriteAtomicSTW, [HB32UnitMem]>;

// Most FP single precision operations are 4 cycles
let Latency = 4 in {
  def : WriteRes<WriteFAdd32, [HB32UnitFPALU]>;
  def : WriteRes<WriteFSGNJ32, [HB32UnitFPALU]>;
  def : WriteRes<WriteFMinMax32, [HB32UnitFPALU]>;
}

let Latency = 2 in {
def : WriteRes<WriteFCvtI32ToF32, [HB32UnitFPALU]>;
def : WriteRes<WriteFCvtF32ToI32, [HB32UnitFPALU]>;

def : WriteRes<WriteFClass32, [HB32UnitFPALU]>;
def : WriteRes<WriteFCmp32, [HB32UnitFPALU]>;
def : WriteRes<WriteFMovF32ToI32, [HB32UnitFPALU]>;
def : WriteRes<WriteFMovI32ToF32, [HB32UnitFPALU]>;
}

//FPU takes 4 cycles (TODO: confirm this)
let Latency = 4 in {
  def : WriteRes<WriteFMul32, [HB32UnitFPALU]>;
  def : WriteRes<WriteFMA32, [HB32UnitFPALU]>;
}

// TODO(Shwet): Verify.
def : WriteRes<WriteFDiv32, [HB32UnitFPDivSqrt]> {                                                                                                                                                                                                                                                       
  let Latency = 32;                                                                                                                                                                                                                                                                                      
  let ReleaseAtCycles = [32];                                                                                                                                                                                                                                                                            
}     

def : WriteRes<WriteFSqrt32, [HB32UnitFPDivSqrt]> {                                                                                                                                                                                                                                                      
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
