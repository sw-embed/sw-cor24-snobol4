# sw-cor24-snobol4

A **SNOBOL4-inspired language implementation** written in **PL/SW**, targeting
the **COR24** 24-bit emulator first, with a later retargeting path to a
24-bit S/370-ish operating system.

## Introduction

SNOBOL4 is a string-oriented language from the 1960s famous for its pattern
matching, dynamic typing, and unusual statement-level control flow (success /
failure gotos). This project reimagines a practical subset of SNOBOL4 as a
bytecode interpreter implemented entirely in PL/SW — a small systems language
that compiles for the COR24 architecture.

The goal is twofold:

1. **Exercise PL/SW** as a serious implementation language by building a
   non-trivial dynamic-language runtime on top of it.
2. **Bring a usable SNOBOL4** to the COR24 emulator (and eventually a
   24-bit S/370-ish host), including strings, patterns, variables, control
   flow, user-defined functions, and a growing set of builtins.

## Summary

The implementation is structured as a classic layered interpreter:

- **Lexer / parser** — reads SNOBOL4 source, including `*` comments and
  continuation lines, producing an internal representation.
- **Compiler** — lowers statements to a compact bytecode with opcodes for
  arithmetic, string ops, assignment, branching, pattern matching, and
  builtin dispatch (e.g. `OP_MOD` for `REMDR`).
- **VM** — a stack/register-style interpreter that executes the bytecode,
  manages the value heap, and handles SNOBOL4's success/failure control
  flow (`:(label)`, `:S(label)`, `:F(label)`).
- **Runtime / builtins** — string, numeric, and I/O primitives
  (`SIZE`, `REMDR`, `DUPL`, pattern constructors, etc.).
- **Host layer** — COR24 I/O, memory, and program loading via PL/SW.

See [`examples/`](examples/) for runnable SNOBOL4 programs, including
`fizzbuzz.sno`, `factorial.sno`, `pattern.sno`, and `dating.sno`.

## Documentation

Detailed design and process docs live under [`docs/`](docs/):

- [PRD](docs/prd.md) — product requirements and scope
- [Architecture](docs/architecture.md) — layered architecture overview
- [Design](docs/design.md) — concrete design decisions
- [Plan](docs/plan.md) — implementation milestones
- [Process](docs/process.md) — development process
- [Tools](docs/tools.md) — toolchain notes
- [Running the PL/SW compiler](docs/running-plsw-compiler.md)
- [MMIO](docs/mmio.md) — memory-mapped I/O on COR24
- [AI agent instructions](docs/ai_agent_instructions.md)
- [Research notes](docs/research.txt)

## Building and running

The project uses [`just`](https://github.com/casey/just) as its task runner.
See [`justfile`](justfile) for available recipes, and
[`docs/running-plsw-compiler.md`](docs/running-plsw-compiler.md) for details
on invoking the PL/SW compiler and running programs on the COR24 emulator.

## Copyright

Copyright (c) 2026 Michael A Wright

(See [`COPYRIGHT`](COPYRIGHT).)

## License

Released under the **MIT License**. See [`LICENSE`](LICENSE) for the full
text.
