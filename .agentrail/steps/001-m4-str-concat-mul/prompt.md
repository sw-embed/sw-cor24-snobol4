Add string concatenation and multiplication to the interpreter.

String concatenation: In SNOBOL4, adjacent values in an expression
are concatenated. For the dating app, we need at minimum:
  OUTPUT = 'text ' VAR ' more text'
  INTS<N> = ',' INTERESTS ','

This requires the parser and AM to handle multi-part expressions
where strings and variables are concatenated.

Multiplication: The dating app uses C * 10 for scoring.
Add TK_STAR token, parse it like +/-, emit OP_MUL AM opcode.
COR24 has a mul instruction.

Add demo .sno files exercising these features.