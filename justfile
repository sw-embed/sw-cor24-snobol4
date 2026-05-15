# SNOBOL4 on PL/SW for COR24

# Build the SNOBOL4 interpreter (modular: sno_main + sno_util + sno_lex + sno_exec)
build:
    bash scripts/build-modular.sh

# Force a full rebuild of the interpreter, ignoring the dep manifest
rebuild:
    bash scripts/build-modular.sh -f

# Produce the canonical shippable .lgo artifact for the shared toolchain.
# The modular linker (link24) emits a raw .bin; bin-to-lgo.sh wraps it as
# the L-record text format mike installs to work/lib/cor24/snobol4.lgo.
#
# NOTE: cor24-emu currently ignores --load-binary when --lgo is set
# (https://... -- dcemu brief pending). Until that's fixed, the runtime
# wrapper should use:  cor24-emu --load-binary snobol4.bin@0 --entry 0
# rather than the planned `cor24-emu --lgo snobol4.lgo`. The .lgo is
# shippable; only the auxiliary-data load path needs the dcemu fix.
build-lgo: build
    bash scripts/bin-to-lgo.sh build/snobol4.bin build/snobol4.lgo
    @echo "Built build/snobol4.lgo ($(wc -c < build/snobol4.lgo) bytes, $(wc -l < build/snobol4.lgo) records)"

# Run a SNOBOL4 program
run file:
    ./scripts/run-snobol4.sh {{file}}

# --- Demo programs ---

# Hello World
hello:
    ./scripts/run-snobol4.sh examples/hello.sno

# Hello with goto (skips second line)
hello-goto:
    ./scripts/run-snobol4.sh examples/hello_goto.sno

# Variables and arithmetic
count:
    ./scripts/run-snobol4.sh examples/count.sno

# SPAN pattern matching
span:
    ./scripts/run-snobol4.sh examples/span.sno

# SPAN failure path
span-fail:
    ./scripts/run-snobol4.sh examples/span_fail.sno

# Pattern matching (commented, aspirational)
pattern:
    ./scripts/run-snobol4.sh examples/pattern.sno

# Multiplication
multiply:
    ./scripts/run-snobol4.sh examples/multiply.sno

# String concatenation
concat:
    ./scripts/run-snobol4.sh examples/concat.sno

# BREAK/REM record parsing
break:
    ./scripts/run-snobol4.sh examples/break.sno

# INPUT reading from data file
input:
    ./scripts/run-snobol4.sh examples/input.sno examples/input.dat

# Array demo
array:
    ./scripts/run-snobol4.sh examples/array.sno

# Conditional-transfer (goto) variants -- regression for the
# combined :S(...) :F(...) parser fix
branches:
    ./scripts/run-snobol4.sh examples/branches.sno

# Arithmetic on function-call results -- regression for the
# dcsno-funcall-arithmetic parser/lowering fix
funcall-arith:
    ./scripts/run-snobol4.sh examples/funcall_arith.sno

# Negative integer OUTPUT -- regression for the EMIT_DEC formatter fix
negative-output:
    ./scripts/run-snobol4.sh examples/negative_output.sno

# Parens around expressions in assignment context -- regression for
# the snobol4-expr-completeness step 2 parser fix
parens-expr:
    ./scripts/run-snobol4.sh examples/parens_expr.sno

# Full expressions in builtin args -- regression for the
# snobol4-expr-completeness step 3 parser/lowering fix
builtin-arg-expr:
    ./scripts/run-snobol4.sh examples/builtin_arg_expr.sno

# 280-stmt program -- regression for the dcftn brief
# dcsno-static-program-size-limit (STMAX raised 256 -> 1024)
many-outputs:
    ./scripts/run-snobol4.sh examples/many_outputs.sno

# 20 KB source file -- regression for the dcftn brief
# dcsno-source-byte-cap (SRC_SIZE raised 12 KiB -> 64 KiB)
large-source:
    ./scripts/run-snobol4.sh examples/large_source.sno

# ANY(class) pattern primitive -- regression for the dcftn brief
# dcsno-any-pattern-fails (ANY was missing entirely; SPAN was the
# only one-char-class workaround)
any-pattern:
    ./scripts/run-snobol4.sh examples/any_pattern.sno

# Long concat expressions -- regression for the dcftn brief
# dcsno-concat-truncation (EPSLOTS bumped 8 -> 16 then 16 -> 32)
concat-chain:
    ./scripts/run-snobol4.sh examples/concat_chain.sno

# Multi-capture patterns -- regression for the dcftn brief
# dcsno-pattern-captures-truncation (PSTK_DEPTH 16 -> 32 + parser
# overflow diagnostic for >EPSLOTS PP slots)
pattern-captures:
    ./scripts/run-snobol4.sh examples/pattern_captures.sno

# Underscore labels -- regression for the dcftn brief
# dcsno-underscore-label (`_` accepted in identifier continuation).
underscore-labels:
    ./scripts/run-snobol4.sh examples/underscore_labels.sno

# Concat with mixed literal/var/builtin operands -- regression for
# dcsno-concat-after-funcall-truncates. Multi-builtin in one
# OUTPUT also exercised.
concat-builtin:
    ./scripts/run-snobol4.sh examples/concat_builtin.sno

# Single-file dcftn FTI-0 workload smoke: RAWINPUT loop +
# BREAK/IDENT dispatch + multi-builtin OUTPUT + underscore labels.
# Catches any regression that would break dcftn's emit_asm.sno.
fti-smoke:
    ./scripts/run-snobol4.sh examples/fti_smoke.sno examples/fti_smoke.dat

# Run all demos -- now diffs each demo's UART output against an
# examples/<name>.expected fixture. Halt-status alone is not
# sufficient (see commit "fix: HAS_BLT lowering walked args wrong"
# for the regression class this catches).
demos: build
    @bash scripts/check-demo.sh hello
    @bash scripts/check-demo.sh hello_goto
    @bash scripts/check-demo.sh count
    @bash scripts/check-demo.sh span
    @bash scripts/check-demo.sh span_fail
    @bash scripts/check-demo.sh multiply
    @bash scripts/check-demo.sh concat
    @bash scripts/check-demo.sh break
    @bash scripts/check-demo.sh input input.dat
    @bash scripts/check-demo.sh array
    @bash scripts/check-demo.sh branches
    @bash scripts/check-demo.sh funcall_arith
    @bash scripts/check-demo.sh negative_output
    @bash scripts/check-demo.sh parens_expr
    @bash scripts/check-demo.sh builtin_arg_expr
    @bash scripts/check-demo.sh many_outputs
    @bash scripts/check-demo.sh large_source
    @bash scripts/check-demo.sh any_pattern
    @bash scripts/check-demo.sh concat_chain
    @bash scripts/check-demo.sh pattern_captures
    @bash scripts/check-demo.sh underscore_labels
    @bash scripts/check-demo.sh concat_builtin
    @bash scripts/check-demo.sh fti_smoke fti_smoke.dat

# --- Tests ---

# Run AM opcode test
test-am:
    ./scripts/build.sh include/descr.msw include/heap.msw include/am.msw src/test_am.plsw

# Run AM lowering test
test-lower:
    ./scripts/build.sh include/descr.msw include/heap.msw include/am.msw src/test_lower.plsw

# Run AM executor test
test-exec:
    ./scripts/build.sh include/descr.msw include/heap.msw include/am.msw src/test_exec.plsw

# Run AM disassembler test
test-amdump:
    ./scripts/build.sh include/descr.msw include/heap.msw include/am.msw src/test_amdump.plsw

# Run pattern node test
test-pat:
    ./scripts/build.sh include/descr.msw include/heap.msw include/pat.msw src/test_pat.plsw

# Run cursor test
test-cursor:
    ./scripts/build.sh include/descr.msw include/heap.msw src/test_cursor.plsw

# Run pattern match test (literal, SPAN, capture)
test-pmatch:
    ./scripts/build.sh include/descr.msw include/heap.msw include/pat.msw src/test_pmatch.plsw

# Run all tests
test: test-am test-lower test-exec test-amdump test-pat test-cursor test-pmatch test-limits test-rawinput-matrix test-stmt-bytecode-cap
    ./scripts/build.sh include/descr.msw include/heap.msw include/trace.msw src/test_descr.plsw
    ./scripts/build.sh include/descr.msw include/heap.msw src/snolib.plsw src/test_snolib.plsw
    ./scripts/build.sh include/descr.msw include/heap.msw src/snolib.plsw src/test_snolib2.plsw
    ./scripts/build.sh include/descr.msw include/heap.msw src/test_alloc.plsw
    ./scripts/build.sh include/descr.msw include/heap.msw src/test_lexer.plsw
    ./scripts/build.sh include/descr.msw include/heap.msw src/test_parser.plsw
    ./scripts/build.sh include/descr.msw include/heap.msw src/test_symtab.plsw

# Regression test for size limits (catches VARS/SYMMAX mismatches, issue #3)
test-limits:
    bash scripts/run-snobol4.sh examples/test_limits.sno examples/test_limits.dat

# RAWINPUT line-count matrix -- catches EOF-garbage and mid-file-halt
# regressions (dcsno-rawinput-{eof-garbage,mid-file-halt}). Iterates
# {line-length, line-count} pairs and asserts reads=N for each.
test-rawinput-matrix: build
    bash scripts/test-rawinput-matrix.sh

# Statement-count vs bytecode buffer regression -- catches the
# AM_CODE_SIZE cliff (dcsno-emit-asm-halt-near-364-stmts). Generates
# N-statement programs at N in {100..1000} and asserts each produces
# exactly N+1 output lines (no silent halt mid-emit).
test-stmt-bytecode-cap: build
    bash scripts/test-stmt-bytecode-cap.sh
