//===- FuzzerInterface.h - Interface header for the Fuzzer ------*- C++ -* ===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
// Define the interface between libFuzzer and the library being tested.
//===----------------------------------------------------------------------===//

// NOTE: the libFuzzer interface is thin and in the majority of cases
// you should not include this file into your target. In 95% of cases
// all you need is to define the following function in your file:
// extern "C" int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size);

// WARNING: keep the interface in C.

#ifndef LLVM_FUZZER_INTERFACE_H
#define LLVM_FUZZER_INTERFACE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

// Define FUZZER_INTERFACE_VISIBILITY to set default visibility in a way that
// doesn't break MSVC.
#if defined(_WIN32)
#define FUZZER_INTERFACE_VISIBILITY __declspec(dllexport)
#else
#define FUZZER_INTERFACE_VISIBILITY __attribute__((visibility("default")))
#endif

// Mandatory user-provided target function.
// Executes the code under test with [Data, Data+Size) as the input.
// libFuzzer will invoke this function *many* times with different inputs.
// Must return 0.
FUZZER_INTERFACE_VISIBILITY int
LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size);

// Optional user-provided initialization function.
// If provided, this function will be called by libFuzzer once at startup.
// It may read and modify argc/argv.
// Must return 0.
FUZZER_INTERFACE_VISIBILITY int LLVMFuzzerInitialize(int *argc, char ***argv);

// Optional user-provided custom mutator.
// Mutates raw data in [Data, Data+Size) inplace.
// Returns the new size, which is not greater than MaxSize.
// Given the same Seed produces the same mutation.
FUZZER_INTERFACE_VISIBILITY size_t
LLVMFuzzerCustomMutator(uint8_t *Data, size_t Size, size_t MaxSize,
                        unsigned int Seed);

// Optional user-provided custom cross-over function.
// Combines pieces of Data1 & Data2 together into Out.
// Returns the new size, which is not greater than MaxOutSize.
// Should produce the same mutation given the same Seed.
FUZZER_INTERFACE_VISIBILITY size_t
LLVMFuzzerCustomCrossOver(const uint8_t *Data1, size_t Size1,
                          const uint8_t *Data2, size_t Size2, uint8_t *Out,
                          size_t MaxOutSize, unsigned int Seed);

// Optional user-provided post-execution effective-input callback.
// Called after LLVMFuzzerTestOneInput returns 0 and before libFuzzer accounts
// for features or corpus state. Data is the exact input just executed and Out
// is separate runtime-owned storage. A non-zero return value is the effective
// input size written to Out; zero uses Data as the effective input. Returning
// more than MaxOutSize without writing past Out rejects this execution; this
// lets the target report an effective input that does not fit the configured
// maximum input length without terminating the fuzzing campaign. libFuzzer
// warns on the first such rejection. When -max_len is not specified,
// effective-input targets receive up to 4096 bytes of additional inferred
// capacity without exceeding the default 1 MiB ceiling.
//
// The effective input drives feature sizing, corpus identity and storage, and
// the next mutation in a mutation chain. Targets are responsible for
// deterministic replay equivalence and idempotence, including
// replay-equivalent sanitizer coverage from this callback itself. The callback
// remains inside ordinary target timing, timeout, allocation, and
// sanitizer-coverage accounting. A non-ASCII result is a fatal contract error
// when libFuzzer runs with -only_ascii=1. Effective-input substitution is not
// compatible with positional -data_flow_trace metadata.
FUZZER_INTERFACE_VISIBILITY size_t LLVMFuzzerCustomGetEffectiveInput(
    const uint8_t *Data, size_t Size, uint8_t *Out, size_t MaxOutSize);

// Optional target marker requiring effective-input support.
// A runtime that implements this extension calls the marker before
// LLVMFuzzerInitialize and fails startup if LLVMFuzzerCustomGetEffectiveInput is
// missing. Targets can use the call to make LLVMFuzzerInitialize reject an
// unmodified runtime instead of silently falling back to identity behavior.
FUZZER_INTERFACE_VISIBILITY void LLVMFuzzerRequireEffectiveInput(void);

// Experimental, may go away in future.
// libFuzzer-provided function to be used inside LLVMFuzzerCustomMutator.
// Mutates raw data in [Data, Data+Size) inplace.
// Returns the new size, which is not greater than MaxSize.
FUZZER_INTERFACE_VISIBILITY size_t
LLVMFuzzerMutate(uint8_t *Data, size_t Size, size_t MaxSize);

#undef FUZZER_INTERFACE_VISIBILITY

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // LLVM_FUZZER_INTERFACE_H
