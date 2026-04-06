Define pattern node representation and constructors.

Create include/pat.msw with:
- Pattern node kinds: PAT_LIT (literal string match), PAT_SPAN (character
  class scan), PAT_ANY (match any single char from class), PAT_LEN (match
  N chars), PAT_ARB (match arbitrary), PAT_CONCAT (sequence), PAT_ALT
  (alternation), PAT_CAP (capture via . operator), PAT_SUCC (terminal
  success), PAT_FAIL (terminal failure)
- BASED record PATNODE: kind(byte), flags(byte), next(ptr), alt(ptr),
  operand(ptr), length(int)

Add pattern constructors to snobol4.plsw or a test file:
- PAT_MAKE_LIT(str_offset) -> allocate PATNODE with kind=PAT_LIT
- PAT_MAKE_SPAN(class_offset) -> PATNODE with kind=PAT_SPAN
- PAT_MAKE_CAP(inner_pat, var_idx) -> capture node

Use the existing heap allocator (HEAP_ALLOC) for node allocation.
Write tests verifying node construction and field access.