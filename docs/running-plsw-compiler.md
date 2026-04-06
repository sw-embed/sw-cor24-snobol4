# Running the PL/SW Compiler -- Multi-Module Strategy for SNOBOL4

## 1. Current PL/SW compilation model

The PL/SW compiler follows a strict pattern:

```
[0..N] .msw macro files  +  [1] .plsw source file  -->  [1] .s assembly file
```

### Invocation (CLI)

```bash
# Simple: one .plsw file, no macros
./scripts/pipeline.sh examples/hello.plsw

# With macros: N .msw files followed by one .plsw file
./scripts/pipeline-dump.sh \
    include/cvt.msw \
    include/ascb.msw \
    examples/chain.plsw
```

### Protocol

The compiler runs on the COR24 emulator. Source is transmitted via UART:

1. Send `c` to enter compile mode.
2. For each .msw file: `FILE:<name>\n<content>\x1E` (record separator).
3. For the main .plsw file: `SOURCE:\n<content>\x04` (end of transmission).
4. Compiler outputs assembly between `--- generated assembly ---` and `--- end assembly ---` markers.

### What .msw files contain

- `MACRODEF` blocks (compile-time code generation templates)
- `BASED` record templates (struct-like declarations for pointer access)
- `%DEFINE` constants
- Shared declarations reused across programs

### What the compiler produces

A single `.s` assembly file (COR24 assembly) containing:

- Runtime startup code
- UART I/O helpers
- All procedures from the .plsw source
- Static data section
- String literal table

The assembly is then run with `cor24-run --run build/<name>.s`.

### Key compiler limits

- One compilation unit (one .plsw file) per invocation
- No separate compilation or linking
- No EXTERNAL symbol resolution across files
- No relocatable object format
- Output is absolute assembly with fixed addresses

## 2. COR24 emulator multi-binary loading

The emulator (`cor24-run`) supports loading multiple binaries at specified addresses:

```bash
cor24-run --run host.s \
    --load-binary module1.bin@0x010000 \
    --load-binary module2.bin@0x020000 \
    --patch 0x0100=0x010000 \
    --patch 0x0103=0x020000 \
    --entry 0
```

### Mechanisms

| Feature | Syntax | Purpose |
|---------|--------|---------|
| Assemble and run | `--run file.s` | Main program |
| Load binary at address | `--load-binary file.bin@0xADDR` | Place pre-assembled code/data |
| Assemble at base address | `--base-addr 0xADDR` | Relocate assembly output |
| Patch memory | `--patch addr=value` | Inject cross-module pointers |
| Set entry point | `--entry addr` | Override start address |

### Address formats

- Hex prefix: `0x010000`
- Hex suffix: `010000h`
- Decimal: `65536`

### Binary formats

- **Raw binary**: loaded byte-for-byte at specified address
- **P24 format**: 18-byte header auto-stripped, body loaded at address
- **LGO format**: text-based load format with embedded addresses (`L<addr><hex>...`)

### How inter-module references work today

There is no linker. Cross-module references are resolved by:

1. Assembling each module at a known base address (`--base-addr`)
2. Loading each binary at its assigned address (`--load-binary`)
3. Patching the host program's memory with module addresses (`--patch`)
4. The host reads patched locations at runtime to find modules

## 3. The SNOBOL4 multi-module problem

The SNOBOL4 implementation requires multiple logical modules:

| Module | Role |
|--------|------|
| descr | Descriptor definitions and helpers |
| heap | Heap header layout, allocator |
| diag | Descriptor dumper, heap walker, tracing |
| am | Abstract machine definitions and macros |
| pattern | Pattern subsystem |
| frontend | Lexer, parser, lowering |
| executor | Statement executor, runtime |
| main | Driver, initialization |

These modules have layered dependencies (descr < heap < diag < am < ...).

### Why a single .plsw file will not work

- The compiler has a 256-node AST pool. Large programs will exhaust it.
- A monolithic file would be unmaintainable.
- Separate compilation enables incremental builds.
- Module boundaries enforce architectural layering.

### Why the current tooling is insufficient

- The compiler produces one assembly file per invocation with no cross-file symbol resolution.
- The emulator can load multiple binaries, but inter-module calls require knowing exact addresses at build time.
- There is no object file format, no symbol export table, and no linker.

## 4. Options for multi-module support

### Option A: Monolithic compilation with macro includes

**Approach**: Keep one .plsw file as the compilation unit. Factor all shared definitions into .msw files. The single .plsw file `%INCLUDE`s everything and contains all procedures.

```bash
./scripts/pipeline-dump.sh \
    include/descr.msw \
    include/heap.msw \
    include/diag.msw \
    include/am.msw \
    src/main.plsw
```

**Pros**:
- Works with existing tooling, no new tools needed
- All symbols resolved within one compilation
- Simple build process

**Cons**:
- AST pool limit (256 nodes) will be hit quickly
- Long compile times on emulator (500M instruction limit)
- No incremental builds
- Monolithic .plsw file grows unwieldy

**Verdict**: Viable only for early milestones when total code is small.

### Option B: Separate compilation with fixed address map

**Approach**: Compile each module as a separate .plsw file at a pre-assigned base address. Use a fixed memory map. Each module exports symbols via a well-known jump table at the start of its region.

```
Memory map:
  0x000000 - 0x00FFFF  main (driver, startup)
  0x010000 - 0x01FFFF  descr + heap (runtime substrate)
  0x020000 - 0x02FFFF  diag (diagnostics)
  0x030000 - 0x03FFFF  am + executor
  0x040000 - 0x04FFFF  pattern
  0x050000 - 0x05FFFF  frontend
  0x080000 - 0x0FFFFF  heap arena
```

Each module starts with a jump table:

```plsw
/* Module header: jump table at base address */
ENTRY_0: PROC; GOTO REAL_PROC_0; END;
ENTRY_1: PROC; GOTO REAL_PROC_1; END;
/* ... */
```

Callers reference entries by base + offset:

```plsw
/* In main.plsw -- call descr module entry 0 */
DCL DESCR_BASE PTR INIT(0x010000);
CALL (DESCR_BASE + 0);  /* if indirect call supported */
```

Build script:

```bash
# Compile each module at its base address
cor24-run --assemble build/descr.s build/descr.bin build/descr.lst --base-addr 0x010000
cor24-run --assemble build/main.s build/main.bin build/main.lst --base-addr 0x000000

# Load all and patch
cor24-run \
    --load-binary build/main.bin@0x000000 \
    --load-binary build/descr.bin@0x010000 \
    --load-binary build/diag.bin@0x020000 \
    --entry 0
```

**Pros**:
- Works with existing emulator tooling
- Each module compiles independently
- Incremental builds possible
- Clean architectural boundaries

**Cons**:
- Requires indirect calls or address patching
- Fixed memory map wastes space in sparse modules
- Jump tables are manual and error-prone
- No automatic symbol resolution
- PL/SW may not support indirect CALL through pointer (needs investigation)

**Verdict**: Workable but fragile. Good as a stepping stone.

### Option C: Module table with build script

**Approach**: Compile modules separately. A build script assembles all modules, extracts their symbol addresses from listing files (.lst), and generates a module table and/or patches.

```
Build pipeline:
  1. Compile each .plsw -> .s (via PL/SW compiler on emulator)
  2. Assemble each .s -> .bin + .lst (via cor24-run --assemble)
  3. Parse .lst files to extract label addresses
  4. Generate a module table (.s or .bin) mapping symbol names to addresses
  5. Generate --patch arguments for cross-module references
  6. Load everything into emulator with patches applied
```

The module table lives at a well-known address (e.g., 0x000100) and contains:

```
Offset  Content
0x0000  module_count (word)
0x0003  mod0_base (ptr)
0x0006  mod0_entry_count (word)
0x0009  mod0_entry_0 (ptr)   -- e.g., DESC_BUILD_INT
0x000C  mod0_entry_1 (ptr)   -- e.g., DESC_DUMP
...
```

**Pros**:
- Automated symbol resolution from listing files
- Module table is inspectable at runtime (good for diagnostics)
- Works with existing assembler and emulator
- Scales to many modules

**Cons**:
- Requires a new build tool (listing parser + table generator)
- Cross-module calls still need indirect dispatch or patching
- Listing file format must be stable and parseable

**Verdict**: Best balance of capability and effort. The build tool is straightforward.

### Option D: Simple linker tool

**Approach**: Build a dedicated linker that reads multiple .s (or a new .obj) files, resolves EXTERNAL symbols, relocates addresses, and produces a single combined binary or LGO file.

Steps:

1. Extend PL/SW compiler to emit `EXTERNAL` declarations as special assembly directives.
2. Assembler produces relocatable object files with symbol tables.
3. Linker reads all object files, resolves references, assigns final addresses, emits one binary.

**Pros**:
- Clean, standard approach
- Automatic symbol resolution
- No manual address management
- Supports CALL by name across modules

**Cons**:
- Requires extending the assembler with a relocatable object format
- Requires building a linker (significant new tool)
- More infrastructure before any SNOBOL4 code runs

**Verdict**: The right long-term solution, but too much upfront work for early milestones.

### Option E: Concatenated assembly with shared symbol file

**Approach**: Compile each .plsw module to .s assembly. Concatenate all .s files into one combined .s file. Assemble once.

A shared symbol file (.msw) declares all cross-module labels as EXTERNAL or provides address constants. Each module's .plsw uses `%INCLUDE` to get the shared declarations.

```bash
# Compile each module
pipeline-dump.sh include/descr.msw src/descr.plsw   # -> build/descr.s
pipeline-dump.sh include/descr.msw src/heap.plsw     # -> build/heap.s

# Concatenate assembly
cat build/descr.s build/heap.s build/main.s > build/snobol4.s

# Assemble and run
cor24-run --run build/snobol4.s
```

**Pros**:
- Simple build process
- Assembly-level symbol resolution works automatically (labels are global in assembly)
- No new tools needed
- Single binary output

**Cons**:
- Assembly files may have conflicting labels (need namespacing convention)
- Each module's assembly includes its own runtime startup -- must strip or guard duplicates
- Concatenation order matters
- Large combined assembly file

**Verdict**: Pragmatic for early milestones. Requires careful label naming conventions.

## 5. Recommended strategy

### Phase 1 (Milestones 0-1): Option A or E

Use **Option A** (monolithic .plsw + many .msw) while the code is small. All shared definitions (descriptor layout, heap headers, macros) go into .msw files. One .plsw file contains all procedures.

If the AST pool limit is hit, switch to **Option E** (concatenated assembly). Each module compiles to .s separately, then concatenate and assemble. Use a label prefix convention:

```
descr__build_int:
heap__alloc:
diag__dump_desc:
```

### Phase 2 (Milestones 2+): Option C

Build a **module table generator** tool:

1. Each module compiles to .s independently.
2. Each module is assembled at a base address with `--base-addr`, producing .bin and .lst.
3. A build tool (Rust CLI) parses .lst files, extracts exported labels, generates a module table binary and a set of `--patch` arguments.
4. A build script loads all modules and the table into the emulator.

### Phase 3 (if needed): Option D

If the project grows enough to justify it, build a proper linker with relocatable object files. This is unlikely to be needed for the scope described in the PRD.

## 6. New tooling needed

### Immediate (Phase 1)

- **Build script** (`scripts/build.sh` or `justfile`): Orchestrate compilation of .msw + .plsw, assembly, and emulator invocation. Pattern after `sw-cor24-plsw/scripts/pipeline-dump.sh`.
- **Label convention document**: Define module prefix rules to avoid conflicts in concatenated assembly.

### Near-term (Phase 2)

- **Listing parser** (`snobol4-link` or similar): Read .lst files from `cor24-run --assemble`, extract label-to-address mappings.
- **Module table generator**: Produce a binary module table and a patch file from extracted symbols.
- **Build orchestrator**: Manage the full compile-assemble-link-load pipeline, track dependencies, support incremental builds.

### Possible future (Phase 3)

- **Relocatable object format**: Extension to the assembler.
- **Linker**: Resolve EXTERNAL symbols, assign addresses, produce final binary.

## 7. Existing tooling summary

| Tool | Location | Role in SNOBOL4 build |
|------|----------|----------------------|
| PL/SW compiler | `sw-cor24-plsw` | Compile .plsw + .msw to .s |
| pipeline.sh | `sw-cor24-plsw/scripts/` | Template for build script |
| pipeline-dump.sh | `sw-cor24-plsw/scripts/` | Template for build script (with artifacts) |
| cor24-run | `sw-cor24-emulator/cli` | Assemble .s, load binaries, patch, execute |
| cor24-run --assemble | `sw-cor24-emulator/cli` | Assemble .s to .bin + .lst at base address |
| cor24-run --load-binary | `sw-cor24-emulator/cli` | Load binary at address |
| cor24-run --patch | `sw-cor24-emulator/cli` | Inject cross-module pointers |
| cor24-run --base-addr | `sw-cor24-emulator/cli` | Set assembly base address |
| markdown-checker | `~/.local/softwarewrighter/bin/` | Validate docs |
| sw-checklist | `~/.local/softwarewrighter/bin/` | Project compliance |

## 8. Open questions

1. **Does PL/SW support indirect CALL through a pointer?** If so, Option B and C become much cleaner. If not, cross-module calls need assembly-level trampolines.
2. **What is the actual AST pool limit behavior?** Does the compiler error gracefully or crash? This determines when to move from Option A to E.
3. **Are assembly listing (.lst) files parseable?** Need to verify the format includes label addresses in a stable, extractable form.
4. **Should the module table be a PL/SW data structure or raw memory?** Using a BASED record template (.msw) for the module table would let modules access it cleanly.
5. **What is the practical compile-time limit?** The 500M instruction limit on the emulator may constrain monolithic compilation.
