# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Run

```bash
cmake -B build && cmake --build build   # build the simulator
./build/sim                              # run the simulator
```

If the compiler lacks `std::format`, install `libfmt-dev` (`sudo apt install libfmt-dev`). After modifying any Verilog source or config file, you must rebuild. If `generated/` doesn't update after Verilog changes, delete `generated/` and rebuild — Verilator's incremental rebuild can be unreliable.

## Project Overview

This is the USTC COD 2025 CPU simulation framework — a Verilator-based co-simulation environment where a student's Verilog CPU (DUT) runs in lockstep with a C++ golden reference model. Diff-testing compares architectural state at each commit to catch CPU implementation bugs. Both RISC-V (RV32I) and LoongArch (LA32R) ISAs are supported, configured at compile time.

## Architecture

### Three-Layer Design

1. **Verilog DUT** (`vsrc/`) — compiled by Verilator into the `VTop` C++ class. The student CPU goes in `vsrc/your_vsrc/`. The top-level wrapper (`vsrc/top.v`) instantiates the CPU, instruction memory, and data memory, and performs virtual-to-physical address translation for memory ports.

2. **Golden Reference Model** (`include/`) — a software CPU that decodes instructions into micro-operation sequences and executes them on a clean architectural state. The reference model defines the correct behavior.

3. **Simulator** (`include/simulator.hpp`) — drives both DUT and golden model in lockstep, comparing state after each commit. Selected at compile time via `Configs::difftest_level`:
   - `DifftestLevel::NONE` — DUT only, no comparison
   - `DifftestLevel::COMMIT` — compares commit-time signals (PC, instr, reg write, dmem write)
   - `DifftestLevel::FULL` — additionally compares all 32 GPRs and entire data memory every cycle

### Golden Model Operation-List Design

The golden model represents each instruction as a `vector<unique_ptr<BaseOperation>>` — a sequence of type-erased callables. Key types in `include/`:

- `isa.hpp` — instruction decode. Takes a 32-bit instruction word, returns a list of `BaseOperation` objects. For example, `beq` produces 3 ops: compute equality temp, compute branch target temp, conditionally assign NPC.
- `argument.hpp` — CRTP argument types (Register, Immediate, Temp, PC, NPC, Halt, Memory access). Each knows how to read/write itself from a `Golden` state object.
- `argument_generator.hpp` — factory for creating Argument objects bound to a specific `Golden` instance.
- `operators.hpp` — free functions (`add`, `subtract`, `assign`, `equal_to`, `conditional_assign`, etc.) that take rvalue-ref Arguments and perform the operation.
- `operation.hpp` — `Operation` binds a function pointer + tuple of ArgumentGenerators. Calling it resolves arguments from the current Golden state and executes.

This means adding a new instruction only requires defining its decode logic in `isa.hpp` (and its operator/argument types if genuinely novel). No other files need changes.

### DUT Wrapper (`include/dut.hpp`)

Wraps the Verilated `VTop`. Provides inner classes `Register` and `DataMemory` for array-like access via Verilator debug ports (sets debug address, calls `eval()`, reads debug data). The `step()` method runs cycles until `commit` is asserted, supporting multi-cycle and pipelined designs.

### Configuration

Two config files must stay in sync:

- `include/configs.hpp` (C++ side) — ISA type, core type, difftest level, waveform dumping, memory base addresses/sizes/init files
- `vsrc/configs/configs.vh` (Verilog side) — memory configs, `CORE_TYPE` (`SINGLE_CYCLE` / `PIPELINE`)

### Memory Map

| ISA | Instr Memory Start | Data Memory Start |
|-----|-------------------|-------------------|
| RISC-V | `0x00400000` | `0x10010000` |
| LoongArch | `0x1C000000` | `0x1C800000` |

Memory init files (`mem/instr.ini`, `mem/data.ini`) are plain-text hex, one 32-bit value per line, no headers, with a trailing blank line.

### Halt

The CPU halts by executing `ebreak` (RISC-V `0x00100073`). The `Top` module detects this and asserts `commit_halt`, which stops the simulator.

### Student CPU Interface

The provided pipelined CPU (`vsrc/your_vsrc/`) is a 5-stage RV32I pipeline (IF→ID→EX→MEM→WB) with forwarding from MEM/WB stages, load-use stall detection, and branch flush (predict-not-taken). The `Top` module defines the required CPU port interface — student implementations must match this interface exactly.
