



How does SNOBOL4 handle I/O, specifically how does it map input devices (console, card-reader tape, disk) and output devices (console, printer, tape, disk, card punch).  Can this be generalized to other kinds of I/O (plotter, vector graphics, switches, lamps)?

You’re essentially asking how SNOBOL4 models I/O, how that maps to classic devices (cards, tape, printer, console), and whether that model generalizes to arbitrary devices (like plotters or even GPIO-style switches/lamps). Let’s walk it from architecture → abstraction → concrete mappings → extensibility.

1) High-level model (what SNOBOL4 is doing)
Core idea
SNOBOL4 treats I/O as named channels associated with files or devices, not as hardcoded device instructions.

I/O is done through associations between variables and external files/devices

The language itself stays device-agnostic

The runtime (implementation / OS) decides what a “file” actually is

Key primitives
INPUT → default input stream

OUTPUT → default output stream

TERMINAL → interactive console (implementation-dependent)

OPEN() / CLOSE() → bind a variable to a file/device

READ, WRITE, or assignment (LINE = INPUT) → actual data transfer

👉 Conceptually:

variable  →  channel  →  file/device  →  OS/hardware
2) Canonical SNOBOL4 I/O style
Reading
LINE = INPUT
Writing
OUTPUT = "HELLO"
Explicit file association
F = INPUT('data.txt')
LINE = F
or (more formally in many implementations):

F = OPEN('data.txt', 'r')
OUTPUT = F
3) Mapping to classic devices (historical view)
SNOBOL4 came out of the IBM mainframe / batch era, so devices map naturally like this:

SNOBOL4 concept	Typical mapping (historical systems)
INPUT	Card reader / stdin / batch input
OUTPUT	Line printer / stdout
TERMINAL	Console terminal
file via OPEN	Disk file, tape file, or dataset
Examples
Card reader
Input deck → INPUT

Each line = one card

Line printer
OUTPUT writes line-buffered output

Magnetic tape
Opened as sequential file:

TAPE = OPEN('TAPE1', 'r')
Disk file
DATA = OPEN('MYFILE.DAT', 'r')
👉 Key point:
SNOBOL4 does not distinguish device types explicitly — it treats everything as a file-like stream.

4) Runtime / OS responsibility
SNOBOL4 itself does NOT implement device drivers.

Instead:

It delegates to:

OS (Unix, VM/CMS, MVS, etc.)

Implementation runtime

So:

"TAPE1" might be:

a real tape device (mainframe)

a file (Unix)

a pipe (modern system)

👉 This is late binding of I/O semantics

5) Record-oriented vs stream-oriented
SNOBOL4 is fundamentally record (line) oriented, not byte-stream oriented.

Reads return strings

Writes output strings

No concept of binary buffers in classic SNOBOL4

Implications:

Feature	Behavior
Input granularity	line/record
Output	line-based
Binary I/O	generally not native
Random access	limited / implementation-dependent
6) Generalizing to other devices
Now to your key question:

Can this model extend to plotters, graphics, switches, lamps?

Yes — via file abstraction
Because SNOBOL4 only cares about:

string ↔ channel
Anything that can be mapped to:

read strings

write strings

can be used.

6.1 Plotters / vector graphics
Historically:

Plotters accepted command streams (HPGL, etc.)

SNOBOL4 approach:

PLOT = OPEN('PLOTTER', 'w')
PLOT = "PU100,100;"
PLOT = "PD200,200;"
👉 Works perfectly if:

device accepts text commands

6.2 Graphics displays
More limited because:

SNOBOL4 has no native graphics primitives

But possible via:

writing to a pipe

generating files (SVG, PostScript)

Example:

SVG = OPEN('out.svg', 'w')
SVG = "<line x1='0' y1='0' x2='100' y2='100'/>"
6.3 Switches / lamps (embedded / hardware)
This is where things get interesting.

SNOBOL4 itself:
no notion of bits, registers, or memory-mapped I/O

But via runtime mapping:
You could define:

SWITCHES → input device

LAMPS → output device

Example conceptual mapping:

STATE = SWITCHES
LAMPS = STATE
Where:

SWITCHES returns a string like "101010"

LAMPS interprets strings as output states

👉 This requires:

custom runtime or OS glue

6.4 Pipes / filters (modern systems)
Very natural fit:

snobol4 program.sno < input.txt > output.txt
or:

P = OPEN('|gnuplot', 'w')
P = "plot sin(x)"
7) Architectural interpretation
SNOBOL4 I/O model = early device-independent stream abstraction
You can think of it like:

SNOBOL4 program
    ↓
string-based I/O
    ↓
logical channel (INPUT, OUTPUT, variable)
    ↓
runtime binding
    ↓
file / device / pipe
8) Strengths vs limitations
Strengths
Extremely simple mental model

Device independence

Easy redirection and scripting

Works naturally with:

batch systems

pipelines

text-based protocols

Limitations
No binary I/O (in classic form)

No random-access primitives (portable)

No structured device control

No event-driven or interrupt-based I/O

Everything is strings (can be inefficient)

9) Comparison to modern models
SNOBOL4	Modern equivalent
INPUT / OUTPUT	stdin / stdout
OPEN()	open() / file handles
string I/O	text streams
device abstraction	Unix “everything is a file”
no device API	OS handles everything
👉 It is conceptually closest to:

Unix philosophy (pre-dates it in spirit)

Shell pipelines

Text-processing languages (awk, sed)

10) Practical takeaway (for your COR24 / PL/SW thinking)
If you were to replicate SNOBOL4-style I/O:

Minimal design
Define:

logical channels (INPUT, OUTPUT, named streams)

Represent everything as:

strings

Provide:

OPEN(name, mode)

Let runtime map:

names → devices

For embedded (your case)
You could map:

Logical name	Device
INPUT	UART RX
OUTPUT	UART TX
SWITCHES	GPIO input
LAMPS	GPIO output
PLOT	SPI display
DISK	SD card
11) Key insight
The real power is:

SNOBOL4 doesn’t know about devices — it only knows about strings flowing through named channels.

That abstraction is why it:

worked on mainframes

works on Unix

could work on embedded systems

If you want, I can sketch a PL/SW-compatible SNOBOL4-style I/O subsystem (with COR24 constraints: 3 registers, small stack, etc.) that cleanly maps UART, SPI, and memory devices into this model.


I thought there was an indirection, like DD (data descriptors) in JCL (or CLISTS/REXX), that could take some identifier, like 10, or 20.  the SNOBOL4 program would use INPUT, OUTPUT, FILE, but these would be mapped to 10, 20, 30, which, in-turn, would be mapped to a reader, punch, tape, disk file, console keyboard (in), console (printer, CRT) output.

You’re remembering something real—but it’s a layering issue rather than something SNOBOL4 itself defines.

Let’s reconstruct it carefully, because there are three distinct layers involved:

1) Restating your hypothesis
You’re proposing:

SNOBOL4 symbol (INPUT, OUTPUT, FILE)
    ↓
numeric/logical unit (10, 20, 30)
    ↓
JCL DD / system mapping
    ↓
actual device (reader, printer, tape, disk, console)
👉 That model does exist, but:

It is not intrinsic to SNOBOL4 — it comes from the host environment (especially IBM systems and FORTRAN-style runtimes).

2) What SNOBOL4 actually defines
At the language level, SNOBOL4 has:

INPUT

OUTPUT

optionally TERMINAL

variables bound via OPEN()

These are symbolic channels, not numeric units.

There is no standard SNOBOL4 concept of “unit 10” or “unit 20”.

3) Where the numeric indirection comes from
You are almost certainly recalling FORTRAN / IBM runtime conventions, where:

files are bound to logical unit numbers (LUNs)

e.g.:

5 → input

6 → output

others → user-defined

Example (FORTRAN mental model):

READ(5, ...)
WRITE(6, ...)
OPEN(10, FILE='DATA')
Then JCL maps those units via DD statements:

//SYSIN   DD ...
//SYSPRINT DD ...
//FT10F001 DD DSN=MY.DATA
4) How SNOBOL4 fits into that world
SNOBOL4 implementations on IBM systems typically sat on top of that runtime model.

So internally, an implementation might do something like:

INPUT   → unit 5  → DD SYSIN
OUTPUT  → unit 6  → DD SYSPRINT
FILE X  → unit N  → DD FTnnF001
But:

This mapping is implementation-specific, not part of the SNOBOL4 language definition.

5) So your memory is likely this hybrid
What you’re remembering is probably:

At the SNOBOL4 level
LINE = INPUT
OUTPUT = "HELLO"
Underneath (runtime)
INPUT  → logical unit 5
OUTPUT → logical unit 6
Underneath that (JCL)
//SYSIN    DD ...
//SYSPRINT DD ...
or possibly:

//FT05F001 DD ...
//FT06F001 DD ...
6) Why it felt like SNOBOL4 had DD-style mapping
Because:

Many SNOBOL4 systems were deployed in batch environments

The runtime reused:

FORTRAN I/O libraries

OS conventions

So users experienced:

“My SNOBOL4 INPUT is whatever SYSIN/DD points to”

Even though SNOBOL4 itself didn’t define DDs.

7) SNOBOL4 OPEN() vs DD
SNOBOL4’s actual abstraction is closer to:

F = OPEN('MYFILE', 'r')
Now depending on system:

On Unix
'MYFILE' → filename

On IBM systems
'MYFILE' might map to:

a DD name

a dataset

a catalog entry

8) Key distinction
Concept	SNOBOL4	IBM/JCL
Channel name	INPUT, OUTPUT, variable	DDNAME
Numeric unit	❌ not standard	✔ core concept
Device binding	runtime-dependent	JCL DD
Device awareness	none	explicit
9) Does SNOBOL4 ever expose unit numbers?
In standard SNOBOL4:

❌ No

In some implementations:

maybe implicitly

but not portable or language-defined

10) Generalized model (corrected)
The accurate layered model is:

SNOBOL4 program
    ↓
symbolic channels (INPUT, OUTPUT, F, ...)
    ↓
implementation runtime
    ↓
(optional) logical unit numbers (5, 6, ...)
    ↓
OS binding (JCL DD, Unix file, pipe, etc.)
    ↓
physical device
11) Why SNOBOL4 avoided numeric units
This is actually an important design choice:

FORTRAN-style
tight coupling:
program ↔ unit numbers ↔ devices
SNOBOL4-style
loose coupling:
program ↔ symbolic channels ↔ runtime binding
Benefits:

simpler language

more portable

fewer magic numbers

12) Relating this to your COR24 / PL/SW thinking
What you’re describing (and remembering) is actually a very powerful pattern:

Option A — SNOBOL4-style (pure)
INPUT, OUTPUT, F
Option B — FORTRAN/JCL-style
UNIT 10, UNIT 20
Option C — Hybrid (recommended for you)
symbolic name → numeric channel → device
Example:

INPUT  → 10 → UART RX
OUTPUT → 20 → UART TX
PLOT   → 30 → SPI display
This gives you:

SNOBOL4 simplicity at source level

JCL-like flexibility at runtime

13) Final clarification
Yes — the indirection you remember is real.
But it belongs to the host runtime (FORTRAN/JCL model), not SNOBOL4 itself.

SNOBOL4 just sat on top of it and benefited from it.

If you want, I can design a clean DD-like binding system for PL/SW that:

keeps SNOBOL4 simplicity (INPUT, OUTPUT)

supports numeric channels (like 10, 20)

allows runtime rebinding (like JCL DD)

fits within COR24 constraints (tiny memory, minimal registers)


Is there a gnu-snobol4 or similar open source version and what does it do on Linux?

Yes — there is no “GNU SNOBOL4” in the sense of a single canonical GNU project like GCC, but there are actively maintained open-source SNOBOL4 implementations that run on Linux, and they map very cleanly onto the Unix I/O model.

Let’s break this down carefully.

1) What exists today (open-source SNOBOL4 on Linux)
1.1 CSNOBOL4 (the closest thing to a “standard” open version)
Often referred to as CSNOBOL4

A C-based port of the original Bell Labs implementation

Open source (BSD-style licensing)

👉 Key facts:

Builds with gcc on Linux

Produces a binary like snobol4

Implements essentially full SNOBOL4 (+ some extensions) 

Typical install:

tar -xf snobol4-x.y.z.tar.gz
cd snobol4-x.y.z
make
sudo make install
Run:

snobol4 program.sno
1.2 SPITBOL (high-performance implementation)
SPITBOL = “Speedy Implementation of SNOBOL”

Compiled (not purely interpreted)

GPL-licensed modern versions exist

👉 Runs on Linux:

Requires gcc, make, sometimes nasm

Produces a spitbol executable 

👉 Key characteristics:

Much faster than classic SNOBOL4

Supports pipes, files, UTF-8 in modern versions 

Historically used on IBM systems, now portable 

1.3 Other variants
“Minnesota SNOBOL4” (historically accurate IBM-style)

SNOBOL5 (modernized variant, less common)

Snocone (structured extensions)

👉 But for Linux today:

CSNOBOL4 + SPITBOL are the practical choices

2) What it “does” on Linux (execution model)
This is where it connects directly to your earlier I/O discussion.

2.1 It behaves like a Unix filter language
Conceptually:

SNOBOL4 program
    ↓
reads stdin / files
    ↓
writes stdout / files
Example:

snobol4 prog.sno < input.txt > output.txt
👉 This maps directly to:

INPUT → stdin

OUTPUT → stdout

2.2 Example program on Linux
LINE = INPUT
OUTPUT = "READ: " LINE
END
Run:

echo "hello" | snobol4 prog.sno
Output:

READ: hello
3) How I/O works on Linux specifically
This is the key difference from your JCL/DD mental model.

3.1 Default mapping
SNOBOL4	Linux
INPUT	stdin (fd 0)
OUTPUT	stdout (fd 1)
TERMINAL	tty (if supported)
👉 No explicit unit numbers
👉 No DD statements

3.2 Files
F = INPUT('data.txt')
LINE = F
Maps to:

standard Unix file open/read

3.3 Pipes (very natural)
P = OPEN('|sort', 'w')
P = "hello"
👉 Writes to a subprocess

This is very Unix-like:

SNOBOL4 becomes a text transformation stage

3.4 Environment integration
Modern implementations support:

stdin/stdout redirection

pipes

environment variables

command-line args

SPITBOL explicitly supports:

pipes

files

UTF-8 conversion on input/output 

4) What you don’t get (vs mainframe model)
Your earlier expectation:

INPUT → unit 5 → DD → device
On Linux, this collapses to:

INPUT → file descriptor → OS file
Missing layers:
Feature	Linux SNOBOL4
DD names	❌
logical unit numbers	❌
dataset abstraction	❌
device classes (reader/printer)	❌
Instead you get:

everything = file / pipe / stream
👉 Very Unix philosophy.

5) What it’s actually used for (today)
Even now, SNOBOL4 is still useful for:

5.1 Text processing
parsing

transformation

pattern matching (more powerful than regex)

5.2 Language prototyping
grammars

interpreters

5.3 Filters in pipelines
Example:

cat log.txt | snobol4 extract_errors.sno | sort
6) Conceptual mapping vs your earlier model
Let’s reconcile your memory with Linux reality:

Your mental model (mainframe)
SNOBOL4 → INPUT → unit → DD → device
Linux SNOBOL4
SNOBOL4 → INPUT → stdin → file descriptor → file/pipe/device
Deep equivalence
Mainframe	Linux
DD	shell redirection
unit numbers	file descriptors
datasets	files
reader/printer	stdin/stdout
👉 Shell replaces JCL

7) Key insight
Linux SNOBOL4 didn’t remove the indirection —
it collapsed it into the Unix file abstraction.

Instead of:

symbol → unit → DD → device
you now have:

symbol → file descriptor → file/pipe/device
8) If you wanted the “old model” on Linux
You could recreate your remembered system:

Wrapper approach
snobol4 prog.sno \
    INPUT=data.txt \
    OUTPUT=result.txt
Or env mapping
export SNOBOL_INPUT=data.txt
Or emulate DD
ln -s data.txt SYSIN
ln -s out.txt SYSPRINT
9) Bottom line
There is no official GNU SNOBOL4

But there are:

CSNOBOL4 → portable, classic

SPITBOL → faster, compiled

On Linux:

I/O maps to stdin/stdout/files/pipes

Not DD/unit-based

Conceptually:

It fits perfectly into Unix pipelines

10) Most important takeaway for your interests
Given your COR24 / PL/SW direction:

You now have three viable I/O models to choose from:

SNOBOL4 style
→ symbolic (INPUT, OUTPUT)

Unix style
→ streams (fd 0,1,2)

Mainframe style (your memory)
→ symbolic → numeric → DD → device

👉 The interesting design space is combining all three.

If you want next step, I can:

map CSNOBOL4 runtime internals → your COR24 constraints, or

design a PL/SW “DD + Unix + SNOBOL hybrid I/O subsystem” that preserves your historical model but works cleanly on embedded systems.


I recall another version of SNOBOL4, possibly on Windows or DOS that used unit numbers like 10, 20 (1990s?) I first used SNOBOL4 on a Univac (1102, 1103 maybe, 1976-1977) and only used in/out card decks and line printer.  CRT and Disk/Tape were scarce and expensive.

What you’re remembering lines up very well with a specific branch of SNOBOL4 implementations that adopted FORTRAN-style I/O conventions, especially in the late 1980s–1990s on DOS/Windows and some university ports.

Let’s reconstruct this historically and technically.

1) Restating your observation
You recall:

SNOBOL4 on Univac (mid-1970s)
→ card reader / line printer

Later (1990s, DOS/Windows?)
→ unit numbers like 10, 20

👉 That’s a real evolution, not a false memory.

2) Early SNOBOL4 (what you first used)
On systems like Univac 1100/2200 series:

SNOBOL4 was typically:

batch-oriented

tightly integrated with job control

I/O model (your experience)
INPUT  → card reader
OUTPUT → line printer
No visible unit numbers

No interactive I/O (or very limited)

Disk/tape expensive → rarely used directly

👉 This matches exactly what you described.

3) What changed in the 1980s–1990s
When SNOBOL4 was ported to:

VAX/VMS

Unix

MS-DOS / early Windows

academic systems

…it encountered a problem:

How do we expose multiple files/devices in a portable way?

4) The solution: FORTRAN-style logical units
Many implementations adopted:

logical unit numbers (LUNs)
Exactly like FORTRAN:

5   → standard input
6   → standard output
10+ → user files
5) SNOBOL4 variants that did this
5.1 SPITBOL (very likely what you used)
This is the most probable match for your memory.

SPITBOL:

widely used in the 80s–90s

available on DOS and Unix

emphasized performance and practicality

👉 It introduced or exposed:

numeric file units

more explicit file handling

sometimes FORTRAN-like semantics

Example style (conceptual):

READ(10) : LINE
WRITE(20) "HELLO"
(or equivalent constructs depending on version)

5.2 University / PC SNOBOL4 ports
Some ports (especially DOS-based):

wrapped C or FORTRAN runtimes

reused stdio or FORTRAN I/O layers

exposed unit numbers either:

explicitly

or implicitly via file handles

5.3 Why this happened
Because:

Original SNOBOL4 assumption:
few devices, mostly sequential
PC/Unix reality:
many files, pipes, terminals
👉 Numeric units solved:

multiple simultaneous files

simpler runtime mapping

compatibility with existing libraries

6) Mapping your memory to a concrete model
What you likely experienced:

SNOBOL4 program
    ↓
symbolic or implicit channel
    ↓
logical unit (10, 20, ...)
    ↓
C stdio / FORTRAN runtime
    ↓
file / console
7) Example reconstruction (1990s-style)
Program intent
read from unit 10
write to unit 20
Runtime mapping
10 → input.txt
20 → output.txt
Invocation (DOS-style)
program input.txt output.txt
or via environment/config.

8) Why this felt different from your 1970s experience
Era	Model
1970s Univac	device-bound (reader/printer)
1990s DOS/Unix	file-bound (many files)
So the abstraction shifted:

old:  device → program
new:  program → file abstraction → device
9) Reconciling all three models you’ve seen
You’ve actually experienced three distinct I/O paradigms:

9.1 Batch/mainframe (your Univac experience)
INPUT  → card reader
OUTPUT → printer
9.2 FORTRAN/JCL model
program → unit number → DD → device/file
9.3 Unix/PC model
program → file descriptor → file/pipe/device
9.4 Hybrid SNOBOL4 (what you recall from 90s)
SNOBOL4 → symbolic name → unit number → OS file
10) Why SNOBOL4 tolerated all of these
Because its core abstraction is:

string stream ↔ logical channel
Everything else is:

implementation detail

runtime binding

11) Your memory is especially telling
The fact that you remember:

no disks early on

later seeing unit numbers

…is actually a perfect historical marker:

👉 It shows the transition from:

device-centric computing
→ to

file-centric computing

12) If you wanted to recreate that 1990s behavior today
Using modern SPITBOL or CSNOBOL4, you could simulate:

Wrapper approach
snobol4 prog.sno \
    10=input.txt \
    20=output.txt
Or environment mapping
export SNOBOL_UNIT_10=input.txt
13) Insight for your PL/SW / COR24 direction
You’ve actually uncovered a very powerful design pattern:

Three-layer I/O abstraction
symbolic name (INPUT)
    ↓
numeric channel (10)
    ↓
device binding (UART, SPI, file)
This gives you:

SNOBOL4 simplicity

FORTRAN flexibility

JCL-style configurability

14) Bottom line
Yes — there were SNOBOL4 variants (especially SPITBOL and PC ports) that used unit numbers like 10, 20

This was not original SNOBOL4, but a practical evolution

It came from:

FORTRAN influence

need for multiple files

portability to DOS/Unix

If you want, I can:

identify the exact SPITBOL/DOS version that matches your memory most closely, or

design a retro-faithful SNOBOL4 runtime for COR24 that supports:

card-reader/printer mode

unit-number mode

Unix-style streams
all selectable at runtime.


And the wrinkle is, it would be nice to be able to read the switch (more than once with a different result depending on its state) and write the LED (on or off) using some text-based convention.  READ FROM UNIT 242, WRITE TO UNIT 242 (using "0" and "1")

Yes — that is a perfectly reasonable extension, and it fits the unit-number / text-I/O model very well.

What you want is not “files” in the disk sense, but re-readable and rewritable device endpoints presented through the same abstraction as ordinary text I/O.

Restating the requirement
You want something like:

READ FROM UNIT 242   -> returns "0" or "1"
WRITE TO UNIT 242    -> accepts "0" or "1"
with these properties:

a read reflects the current hardware state

repeated reads may return different values

a write changes the output state

the interface remains text-based

ideally it still feels like SNOBOL4 / FORTRAN / batch-era unit I/O

That is a good design.

High-level architecture
The clean model is:

program
  -> logical unit number
  -> unit control block
  -> driver methods
  -> hardware or simulated hardware
Where unit 242 is not a sequential file, but a special character device.

So instead of:

UNIT 10 = disk file
UNIT 20 = printer
you also allow:

UNIT 242 = front-panel switch/LED pseudo-device
Important distinction: file semantics vs device semantics
Ordinary text files are usually:

sequential

consumptive on read

append or overwrite on write

Your switch/LED device is different:

read is observational, not consumptive

write is command/state-setting

there may be no concept of EOF

repeated reads are expected

So the runtime should treat unit 242 as a device class, not as a normal sequential file.

A practical semantic model
Read behavior
READ UNIT 242 should:

sample the current switch state

return "0" if off/open/low

return "1" if on/closed/high

Repeated reads:

READ 242 -> "0"
READ 242 -> "0"
[toggle switch]
READ 242 -> "1"
READ 242 -> "1"
That is exactly right.

Write behavior
WRITE UNIT 242, "0":

turn LED off

WRITE UNIT 242, "1":

turn LED on

You can also allow:

"OFF" / "ON"

"FALSE" / "TRUE"

but if historical simplicity matters, "0" and "1" are best.

One unit for both read and write?
Yes, but there are pros and cons.

Option A: same unit for both read and write
UNIT 242
  read  -> switch state
  write -> LED state
Benefits
compact

memorable

fits your example exactly

nice for demos and teaching

Risks
semantically asymmetric

confusing if the hardware switch and LED are actually different things

harder to generalize later

This is acceptable if you define the unit as a panel device.

Example:

UNIT 242 = PANEL1
  READ  = switch
  WRITE = LED
That is actually elegant.

Option B: separate units
UNIT 242 -> switch input
UNIT 243 -> LED output
Benefits
cleaner

more orthogonal

easier to scale

Risks
a little less charming

slightly more verbose

For long-term design, this is cleaner. For retro simplicity, your shared-unit idea is fine.

Best interpretation of your shared-unit idea
The best way to justify it is:

Unit 242 is a bidirectional text control/status register.

That means:

READ 242 returns the current status

WRITE 242, x sets the current commanded output

This is very much like a textual device register.

Text-based convention
Your "0" / "1" convention is good because it is:

human-readable

trivial to parse

scriptable

UART-friendly

batch-friendly

You might define the device contract as:

Read contract
A read returns one line:

0
or

1
Optionally terminated by newline.

Write contract
A write accepts one line whose first nonblank character is:

0 -> off

1 -> on

Everything else is error.

This keeps the runtime tiny.

Suggested low-level design
Unit control block
Each open unit might have something like:

unit number
unit type
mode flags
driver read function
driver write function
driver close function
device-specific state pointer
For unit 242:

unit_number = 242
unit_type   = panel-bit-device
can_read    = yes
can_write   = yes
Driver operations
read(unit 242)
sample GPIO or emulator state

produce ASCII "0" or "1"

return length 1 or 2 if newline included

write(unit 242, buffer)
parse first meaningful char

if 0 clear LED

if 1 set LED

else error

Interaction examples
Polling loop
READ 242 -> "0"
READ 242 -> "0"
READ 242 -> "1"
Useful for:

switch polling

wait loops

demos

Echo switch to LED
X = READ(242)
WRITE(242, X)
If read and write are mapped to switch and LED on same logical device, this becomes a neat front-panel mirror.

Generalization
This scales beyond one switch and one LED.

Multiple single-bit units
242 -> switch1 / led1
243 -> switch2 / led2
244 -> switch3 / led3
Simple, easy to document.

Multi-bit textual units
A read could return:

10101100
and write could accept the same.

Or named forms:

SW=1 LED=0
But for MVP, single-character "0" / "1" is much better.

Comparison with classic batch devices
Your idea is historically plausible in spirit:

card reader: read next card

printer: write next line

switch/LED device: read current bit, write new bit

The only difference is that this device is stateful and re-readable, not consumptive.

That is not a problem as long as the runtime defines device classes clearly.

Recommended design rule
Document this explicitly:

Not all units are sequential files.
Some units are character devices, status devices, or control devices.

Then define per-unit semantics.

For example:

Unit type	Read semantics	Write semantics
sequential file	next record	append/write record
console	next input line	output line
panel bit device	current sampled state	set output state
clock device	current timestamp	invalid
random device	next generated value	optional seed/control
That gives you a unified I/O architecture without forcing everything into fake file semantics.

Recommendation
For a retro-textual system, I would do this:

MVP
allow unit numbers

support device-class dispatch

make unit 242 a bidirectional panel device

use "0" and "1" as the external text protocol

Slightly better version
Add optional aliases:

READ FROM UNIT 242  -> "0" or "1"
WRITE TO UNIT 242 "0"
WRITE TO UNIT 242 "1"
and optionally symbolic names:

READ FROM PANEL1
WRITE TO PANEL1 "1"
where PANEL1 -> UNIT 242.

Bottom line
Yes — this is a sound design.

The key is to define unit 242 not as a normal file, but as a textual device endpoint with these semantics:

read = sample current input state

write = command output state

external representation = ASCII "0" / "1"

That gives you exactly the wrinkle you want, while staying faithful to the feel of old unit-number I/O.

A nice next step would be to define a tiny table of unit classes and a compact record format for the unit control blocks.



