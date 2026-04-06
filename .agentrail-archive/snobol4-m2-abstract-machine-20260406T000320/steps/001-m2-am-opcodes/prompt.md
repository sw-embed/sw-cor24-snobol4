Define AM opcode constants and the AM code buffer.

Create include/am.msw with:
- Opcode constants (%DEFINE): LOAD_INT, LOAD_STR, LOAD_VAR,
  STORE_VAR, ADD, SUB, PRINT_INT, PRINT_STR, PRINT_NL,
  BR, BR_SUCC, BR_FAIL, HALT, NOP
- Each opcode is a single byte
- Operands follow the opcode: 1-3 bytes depending on opcode

Create AM code buffer in snobol4.plsw:
- DCL AM_CODE(512) BYTE -- linear bytecode buffer
- DCL AM_PC INT -- program counter for emission
- AM_EMIT_OP: emit an opcode byte
- AM_EMIT_BYTE: emit a data byte
- AM_EMIT_WORD: emit a 24-bit word (3 bytes, little-endian)
- AM_INIT: reset code buffer

Write a test that emits a simple AM sequence (LOAD_INT 42, PRINT_INT, HALT)
and verifies the bytes in the buffer are correct.