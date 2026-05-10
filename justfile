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

# Run all demos
demos: hello hello-goto count span span-fail multiply concat break input array branches funcall-arith negative-output parens-expr builtin-arg-expr

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
test: test-am test-lower test-exec test-amdump test-pat test-cursor test-pmatch test-limits
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
