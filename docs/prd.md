# PRD — SNOBOL4 on PL/SW for COR24

## 1. Purpose

Build a **SNOBOL4-inspired implementation** using **PL/SW** as the implementation language, targeting the **COR24 emulator and COR24-TB-style environment first**, with a later retargeting path to a **24-bit S/370-ish operating system**.

The implementation should follow the historical spirit of **SIL** without reproducing it literally. The project should instead define a **PL/SW-based abstract machine** for SNOBOL semantics and use **layered recursive macros** plus selective inline COR24 assembler to realize that machine efficiently and portably.

## 2. Product goals

### 2.1 Primary goals

1. **Dogfood PL/SW** as a serious systems language.
2. Build a **macro-layered abstract machine** suitable for dynamic languages.
3. Support a meaningful **SNOBOL4-compatible core**, especially its pattern-oriented execution model.
4. Be practical on **COR24** with:
   - 24-bit words
   - very few registers
   - 1M heap
   - small fast stack
5. Create tooling in PL/SW to support bring-up:
   - heap walkers
   - descriptor dumpers
   - trace tools
   - validators
   - debuggers
6. Keep a clean retargeting path to a later **24-bit S/370-ish** implementation.

### 2.2 Secondary goals

1. Produce a design that is educational and inspectable.
2. Make runtime structures easy to dump and trace.
3. Prefer regularity and debuggability over early micro-optimization.
4. Preserve room for later optimizations such as denser AM forms, threaded dispatch, or AOT lowering.

## 3. Non-goals

### 3.1 Near-term non-goals

1. Full bit-for-bit compatibility with every historical SNOBOL4 implementation.
2. High performance as the first priority.
3. Self-hosting the implementation in SNOBOL4.
4. Immediate support for full SPITBOL-style compilation or aggressive native-code generation.
5. Early support for all numeric types, all tables, all arrays, and all edge-case I/O semantics.
6. Early optimization specifically for future 31-bit environments.

### 3.2 Scope control non-goals

1. Do not bury semantics in raw assembler.
2. Do not rely on C as the implementation substrate.
3. Do not map deep pattern recursion onto the small machine stack.

## 4. Users and use cases

## 4.1 Primary user

The primary user is the system designer implementing and evolving:

- PL/SW
- COR24 runtime infrastructure
- COR24 monitor / OS components
- future S/370-ish runtime and OS components

## 4.2 Primary use cases

1. Run small SNOBOL4-style programs under the COR24 emulator.
2. Stress-test PL/SW macro expansion and low-level runtime facilities.
3. Explore descriptor-based runtime organization.
4. Exercise heap allocation, symbolic tables, pattern matching, and backtracking.
5. Use built-in diagnostic tools to inspect runtime state.
6. Later retarget the same semantic core to a different 24-bit machine environment.

## 5. Problem statement

SNOBOL4 is a difficult language to implement on constrained machines because it combines:

- dynamic typing
- string-heavy execution
- success/failure-oriented control flow
- first-class pattern behavior
- speculative matching with rollback
- heap-driven runtime objects

COR24 further constrains the implementation because it offers:

- only three general-purpose registers
- a small fast stack
- 24-bit machine words

The product therefore needs an implementation architecture that:

1. is **portable at the semantic level**
2. is **macro-friendly**
3. does not depend on register abundance
4. keeps most dynamic language state in the heap rather than on the fast stack
5. remains inspectable and debuggable during bring-up

## 6. Product requirements

## 6.1 Language substrate requirements

1. The implementation **must be written in PL/SW**.
2. The implementation **must support recursive macro layering** as a first-class design technique.
3. The implementation **may use inline COR24 assembler** for low-level primitives and hot spots.
4. The implementation **must not require C** for runtime semantics.

## 6.2 Architecture requirements

1. The implementation **must define an abstract machine** for SNOBOL semantics.
2. The abstract machine **must be independent of COR24 bit layout details** except through lower layers.
3. The runtime **must use explicit heap-backed stacks** for major semantic state such as backtracking.
4. The design **must keep descriptor physical layout target-specific**, while descriptor semantics remain target-neutral.
5. The parser/frontend and runtime/execution model **must be separated by an intermediate representation or AM form**.

## 6.3 Runtime requirements

1. The runtime must support at least:
   - integers
   - strings
   - variables
   - labels / transfers
   - success/failure execution results
   - basic pattern execution
2. The runtime must use a **descriptor-based object model**.
3. The runtime must define **uniform heap headers** for heap objects.
4. The runtime must support **GC root enumeration**.
5. The runtime must support **rollback of speculative pattern-side effects**.

## 6.4 Tooling requirements

The product must include tools or libraries for:

1. descriptor dumping
2. heap walking
3. heap consistency checking
4. stack dumping
5. symbol table dumping
6. pattern graph dumping
7. execution tracing
8. optional assertion/trap support

## 7. Functional scope

## 7.1 Initial functional subset

### Frontend

- source reader
- lexer
- parser for minimal SNOBOL4-like forms
- lowering into AM or equivalent runtime form

### Runtime core

- descriptor creation and access
- symbol table
- assignment
- integer and string literals
- statement execution
- success/failure result propagation
- labels and transfers

### Pattern subset

- literal pattern matching
- concatenation
- alternation
- subject cursor tracking
- backtrack frame creation/restoration
- simple captures or assignments with rollback logging

### Diagnostics

- dumps and traces sufficient for bring-up

## 7.2 Later functional scope

- broader builtin library
- arrays and tables
- richer pattern forms
- file or device I/O
- user functions
- more compatibility semantics
- denser code forms
- S/370-ish retargeting

## 8. Nonfunctional requirements

## 8.1 Portability

1. The semantic core should be portable across 24-bit targets.
2. Character classification and scanner tables must be centralized.
3. Pointer/integer equivalence must not be assumed blindly.

## 8.2 Debuggability

1. Runtime state must be easily inspectable.
2. Every major object type should be dumpable.
3. The heap should be walkable and validate-able.
4. The pattern engine should expose trace hooks.

## 8.3 Maintainability

1. Macro layers must have clear responsibilities.
2. Machine-level details should be confined to the lowest layers.
3. Semantic logic should remain in PL/SW or macro-expanded PL/SW rather than assembler fragments.

## 8.4 Performance

1. The first milestone favors correctness and visibility.
2. Hot spots may use inline assembler.
3. The abstract machine should allow future optimization without semantic redesign.

## 9. Success criteria

The project is successful in its first major phase when all of the following are true:

1. A nontrivial subset of SNOBOL4-like programs runs under COR24.
2. The runtime uses explicit descriptors and heap-backed semantic stacks.
3. Diagnostic tools can dump and validate runtime structures.
4. Pattern matching works with explicit backtracking and rollback.
5. The architecture is documented clearly enough to guide a later 24-bit S/370-ish retarget.

## 10. Risks

### Major risks

1. Macro-layer complexity becomes hard to reason about.
2. Register pressure creates inefficient or fragile generated code.
3. Pattern execution consumes too much heap or stack.
4. GC, rollback, and tracing interact poorly.
5. Parser and runtime become overly coupled.

### Risk response

1. Keep the AM boundary explicit.
2. Use heap-backed semantic stacks.
3. Build diagnostics early.
4. Keep assembler islands small and mechanical.
5. Prefer regular data layouts and uniform headers.
