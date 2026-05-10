# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Run

```bash
cmake -B build && cmake --build build   # build the simulator
./build/sim                              # run the simulator
```

If the compiler lacks `std::format`, install `libfmt-dev` (`sudo apt install libfmt-dev`). After modifying any Verilog source or config file, you must rebuild. If `generated/` doesn't update after Verilog changes, delete `generated/` and rebuild — Verilator's incremental rebuild can be unreliable.

## Project Overview

USTC COD 2025 CPU simulation framework — a Verilator-based co-simulation environment where a student's Verilog CPU (DUT) runs in lockstep with a C++ golden reference model. Diff-testing compares architectural state at each commit to catch CPU implementation bugs. Both RISC-V (RV32I) and LoongArch (LA32R) ISAs are supported, configured at compile time.

## Architecture

### Three-Layer Design

1. **Verilog DUT** (`vsrc/`) — compiled by Verilator into the `VTop` C++ class. The student CPU goes in `vsrc/your_vsrc/`. The top-level wrapper (`vsrc/top.v`) instantiates the CPU, instruction memory, and data memory, and performs virtual-to-physical address translation for memory ports.
2. **Golden Reference Model** (`include/`) — a software CPU that decodes instructions and executes them on a clean architectural state. The reference model defines the correct behavior.
3. **Simulator** (`include/simulator.hpp`) — drives both DUT and golden model in lockstep, comparing state after each commit. Level selected via `Configs::difftest_level`:
   - `DifftestLevel::NONE` — DUT only, no comparison
   - `DifftestLevel::COMMIT` — compares commit-time signals (PC, instr, reg write, dmem write)
   - `DifftestLevel::FULL` — additionally compares all 32 GPRs and entire data memory every cycle

### Golden Model Operation-List Design

The golden model represents each instruction as a `vector<unique_ptr<BaseOperation>>` — a sequence of type-erased callables. Key types in `include/`:

- `isa.hpp` — instruction decode. Takes a 32-bit instruction word, returns a list of `BaseOperation` objects.
- `argument.hpp` — CRTP argument types (Register, Immediate, Temp, PC, NPC, Halt, Memory access).
- `argument_generator.hpp` — factory for creating Argument objects bound to a specific `Golden` instance.
- `operators.hpp` — free functions (`add`, `subtract`, `assign`, `equal_to`, `conditional_assign`, etc.).
- `operation.hpp` — `Operation` binds a function pointer + tuple of ArgumentGenerators.

Adding a new instruction only requires defining its decode logic in `isa.hpp` (and its operator/argument types if genuinely novel).

### DUT Wrapper (`include/dut.hpp`)

Wraps the Verilated `VTop`. Provides inner classes `Register` and `DataMemory` for array-like access via Verilator debug ports. The `step()` method runs cycles until `commit` is asserted, supporting multi-cycle and pipelined designs.

### Configuration

Two config files must stay in sync:

- `include/configs.hpp` (C++ side) — ISA type (`IsaType::RISC_V` / `IsaType::LOONGARCH`), core type (`CoreType::SIMPLE` / `CoreType::COMPLETE`), difftest level, waveform dumping, memory base addresses/sizes/init files
- `vsrc/configs/configs.vh` (Verilog side) — memory configs, `CORE_TYPE` (`SINGLE_CYCLE` / `PIPELINE`)

### Memory Map

| ISA | Instr Memory Start | Data Memory Start |
|-----|-------------------|-------------------|
| RISC-V | `0x00400000` | `0x10010000` |
| LoongArch | `0x1C000000` | `0x1C800000` |

Memory init files (`mem/instr.ini`, `mem/data.ini`) are plain-text hex, one 32-bit value per line, no headers, with a trailing blank line.

### Halt

The CPU halts by executing `ebreak` (RISC-V `0x00100073`). The decoder detects it (`halt = is_ebreak`), the signal propagates through all pipeline stages, and the commit output asserts `commit_halt`, which stops the simulator.

## Pipelined CPU (`vsrc/your_vsrc/CPU.v`)

A 5-stage RV32I pipeline: IF → ID → EX → MEM → WB.

### Module inventory

| Module | Purpose |
|--------|---------|
| `PC.v` | Program counter with stall support |
| `IF_ID.v` | IF/ID pipeline register (has `en`, `stall`, `flush`; produces `commit_d = 1'b1`) |
| `decoder.v` | RV32I decode — opcode, ALU control, immediates, branch type, dmem access, halt |
| `regfiles.v` | 32-entry register file; x0 hardwired to 0 on both reads and writes |
| `ID_EX.v` | ID/EX pipeline register (has `en`, `stall`, `flush`) |
| `Forwarding.v` | Forward from MEM (`alu_res`) and WB (`rf_wd`); MEM takes priority |
| `ALU.v` | Arithmetic/logic unit |
| `BRANCH.v` | Branch/JAL/JALR NPC selection |
| `PipelineControl.v` | Load-use stall detection and branch flush |
| `EX_MEM.v` | EX/MEM pipeline register (**no** `en` port — latches every cycle) |
| `SLU.v` | Store/load unit — handles byte/halfword/word access |
| `MEM_WB.v` | MEM/WB pipeline register (**no** `en` port — latches every cycle) |
| `MUX.v` / `MUX2.v` | 2-input / 4-input multiplexers |

### Pipeline register port conventions

`IF_ID` and `ID_EX` have `en`, `stall`, `flush` ports. `EX_MEM` and `MEM_WB` do **not** have `en` — they latch every cycle (`always @(posedge clk) if (rst) ... else ...`). Passing `.en(global_en)` to EX_MEM or MEM_WB causes a compilation error.

### Pipeline control

- **Load-use stall**: When the EX stage instruction is a load (`rf_wd_sel == 2'b10`) writing to a register that the ID stage instruction reads as `rs1` or `rs2`, PC and IF_ID are stalled while ID_EX is flushed (inserted with a NOP).
- **Branch flush**: When `npc_sel != 0` (branch taken / JAL / JALR), IF_ID is flushed and ID_EX is flushed.
- Stall conditions must be gated by `global_en`.

### Forwarding

Two-level forwarding: MEM stage ALU result (`rf_wa_mem`, `rf_we_mem`, `alu_res_mem`) and WB stage result (`rf_wa_wb`, `rf_we_wb`, `rf_wd_wb`). MEM stage takes priority over WB. x0 is never forwarded (`rf_wa_* != 5'b0` check).

## CPU-to-Simulation-Framework Adaptation

The simulation framework reads commit signals from the CPU to compare against the golden model. These signals report what each retired instruction wrote, and must come from the **WB stage** — not delayed by an extra register, since WB values already pass through the MEM/WB pipeline register.

### Commit port interface

```verilog
output  commit,            // 1 if an instruction commits this cycle
        commit_halt,       // 1 if this instruction is ebreak (0x00100073)
        commit_reg_we,     // register file write enable
        commit_dmem_we;    // data memory write enable
output [31:0] commit_pc, commit_instr, commit_reg_wd, commit_dmem_wa, commit_dmem_wd;
output [ 4:0] commit_reg_wa;
input  [ 4:0] debug_reg_ra;     // for FULL difftest: read arbitrary GPR
output [31:0] debug_reg_rd;
```

### Commit signal wiring (WB stage)

```
commit           = commit_w;
commit_pc        = pc_w;
commit_instr     = inst_w;
commit_halt      = halt_w;                    // from decoder, through full pipeline
commit_reg_we    = rf_we_w;
commit_reg_wa    = rf_wa_w;
commit_reg_wd    = (rf_wa_w == 5'b0) ? 0 : rf_wd_w;   // x0 always writes 0
commit_dmem_we   = dmem_we_w;                // from EX_MEM, through MEM_WB
commit_dmem_wa   = alu_res_w;                // store address
commit_dmem_wd   = dmem_wd_w;                // SLU-processed write data
```

Critical details:

- **x0 write masking**: `commit_reg_wd` must output 0 when `rf_wa_w == 5'b0`, even though the ALU computes a non-zero value. The golden model checks this.
- **dmem commit signals**: Must come from MEM_WB outputs (`dmem_we_w`, `alu_res_w`, `dmem_wd_w`), not hardwired to 0. The `dmem_wd_m` input to MEM_WB is `slu_wd_out` (SLU-processed write data from the MEM stage).
- **halt signal**: Must propagate through the full pipeline: `decoder → ID_EX → EX_MEM → MEM_WB → commit_halt`. Calculated in ID as `inst == 32'h00100073` (ebreak).
- **Register file write timing**: `rf_we` to regfiles must be `rf_we_w & commit_w` so writes only happen when the WB stage has a valid instruction.

### debug_reg_rd

The register file's debug port must handle x0 (always return 0) and write-through forwarding:

```verilog
assign debug_reg_rd = (debug_reg_ra == 5'b0) ? 32'b0 :
                      (rf_we && (debug_reg_ra == rf_wa)) ? rf_wd :
                      reg_file[debug_reg_ra];
```

## Common Issues

- **Verilator PINNOTFOUND/PINMISSING**: When adding a new signal through the pipeline, every pipeline register between decode and WB must carry that signal. Missing a port on any stage produces these errors.
- **Commit timing skew**: Do not add an extra register stage between WB and the commit outputs. WB signals are already registered by MEM_WB. An extra register causes the commit report to lag one cycle behind the actual register/memory writes, producing difftest mismatches on `gr[x]` and `dmem[x]`.
- **dmem_we in MEM stage**: Must be gated by `commit_m`: `dmem_we = dmem_we_m & commit_m`. This prevents stores from writing memory when the pipeline slot is invalid (e.g., after a flush).
