# SNOBOL4 on PL/SW for COR24

# Build the SNOBOL4 interpreter
build:
    ./scripts/build.sh include/descr.msw include/heap.msw include/am.msw src/snobol4.plsw

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

# Pattern matching (target -- not yet supported)
pattern:
    ./scripts/run-snobol4.sh examples/pattern.sno

# Run all demos
demos: hello hello-goto count

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
test: test-am test-lower test-exec test-amdump test-pat test-cursor test-pmatch
    ./scripts/build.sh include/descr.msw include/heap.msw include/trace.msw src/test_descr.plsw
    ./scripts/build.sh include/descr.msw include/heap.msw src/test_snolib.plsw
    ./scripts/build.sh include/descr.msw include/heap.msw src/test_snolib2.plsw
    ./scripts/build.sh include/descr.msw include/heap.msw src/test_alloc.plsw
    ./scripts/build.sh include/descr.msw include/heap.msw src/test_lexer.plsw
    ./scripts/build.sh include/descr.msw include/heap.msw src/test_parser.plsw
    ./scripts/build.sh include/descr.msw include/heap.msw src/test_symtab.plsw
