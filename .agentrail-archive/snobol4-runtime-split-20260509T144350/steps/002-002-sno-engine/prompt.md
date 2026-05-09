Step 2 of the snobol4-runtime-split saga: consolidate the engine. Move the lexer/parser/AM-emit code from sno_lex.plsw and the lowering/executor/pattern-matching/builtins from sno_exec.plsw into a single linkable engine module src/sno_engine.plsw that compiles cleanly stripped of the runtime library extracted in step 1 (src/snolib.plsw).

Decisions to make in step 2:
- Whether sno_engine should %INCLUDE snolib (textual) or link against it (link24). Step 1 went with the %INCLUDE model because the existing build was single-binary; step 2 is the right place to switch to separate compilation.
- Whether SBPUT/SBSAVE/PUT_DEC/EMIT_DEC stay in sno_engine (current location: sno_util.plsw) or move into a runtime-library extension. They touch the SB global from snoglob.msw; that ownership question is what the saga prompt deferred.
- How to keep the modular build of the interpreter working through the transition. The current 4-module pipeline (sno_main + sno_util + sno_lex + sno_exec) needs to evolve into the 3-module shape (snobol4 + sno_engine + snolib) without breaking just build / just demos.

Unblock src/sno_engine.plsw in .gitignore as part of this step (src/snobol4.plsw stays blocked until step 3). Verify the full demo suite still passes.