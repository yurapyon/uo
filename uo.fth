: mkspc ( ct -- previous-here )
  here @ swap allot align ;

: save, ( addr addr-len -- new-addr addr-len )
  tuck
  here @ swap move
  dup mkspc swap ;

: k 1024 * ;

: u16 2 chars ;
: u16s u16 * ;
: u16! ( value addr -- ) over 8 rshift over 1+ c! c! ;
: u16@ dup c@ swap 1+ c@ 8 lshift or ;

\ ===

0 cell field >array-mem
  cell field >array-here
constant array

: <array> 2dup >array-mem ! >array-here ! ;
: array>stk dup >array-mem @ swap >array-here @ ;
: array-size array>stk swap - ;
: array-ct swap array-size swap / ;
: adv-array swap >array-here +! ;
: align-array ( array align -- )
  >r
  >array-here dup @
  r> aligned-to swap ! ;
\ ( idx array item-size -- addr )
: >array[] rot * swap >array-mem @ + ;

: mkarray ( array-size "mem-name" "array-name" -- )
  create here @ swap allot
  create here @ array allot
  <array> ;

\ ===

32 k constant icount
1 k constant lcount
1 k constant acount

\ ===

  0 enum %lit
    enum %empty
    enum %abs
constant %rel

0   1 +field >atype
  u16 aligned-to
  u16 +field >avalue
constant arg

: <arg> >r
  r@ >avalue u16!
  r> >atype c! ;

: to-acell swap 16 lshift or ;
: from-acell dup 16 rshift swap 0xffff and ;

: is-lit    >atype c@ %lit = ;
: is-empty  >atype c@ %empty = ;
: is-abs    >atype c@ %abs = ;
: is-rel    >atype c@ %rel = ;
: is-access dup is-abs swap is-rel or ;

: mklit  %lit swap to-acell ;
: mkempty %empty 0 to-acell ;
: mkabs  %abs swap to-acell ;
: mkrel  %rel swap to-acell ;

\ ===

0 cell field >tag-name
  cell field >tag-len
  cell field >tag-addr
constant tag

: tag>string dup >tag-name @ swap >tag-len @ ;
: tag~= tag>string rot tag>string string= ;
: transfer-addr ( src dest -- ) >tag-addr swap >tag-addr @ swap ! ;

: <tag> ( name len addr tag-addr -- )
  >r
  r@ >tag-addr !
  save,
  r@ >tag-len !
  r> >tag-name ! ;

\ ===

0  cell field >idef
3 arg * field >args
   cell aligned-to
constant instr

: >arg[] >args swap arg * + ;

( acell acell acell idef instr -- )
: <instr> >r
  r@ >idef !
  from-acell 0 r@ >arg[] <arg>
  from-acell 1 r@ >arg[] <arg>
  from-acell 2 r> >arg[] <arg> ;

icount instr * mkarray imem instrs

: instr-ct instrs instr array-ct ;
: >instr[] instrs instr >array[] ;

: instr,
  instrs >array-here @ <instr>
  instrs instr adv-array ;

\ ===

0 value phere

: tag, ( name len addr tag-array -- )
  >r
  r@ >array-here @ <tag>
  r> tag adv-array ;

: >tag[] tag >array[] ;

lcount tag * mkarray lmem labels
acount tag * mkarray amem accesses

: label, phere labels tag, ;
: label-ct labels tag array-ct ;
: >label[] labels >tag[] ;

: access, 0 accesses tag, ;
: access-ct accesses tag array-ct ;
: >access[] accesses >tag[] ;

\ === resolving

: !access-not-found
  ." label not found for access: "
  tag>string type cr
  panic ;

: unwrap'access>label 0= if !access-not-found then ;

: access>label ( access -- label t/f )
  label-ct 0 ?do
    i >label[] 2dup tag~=
    if unloop nip true exit
    else drop then
  loop
  false ;

: resolve-access dup access>label transfer-addr ;

: resolve-accesses
  access-ct 0 ?do
    i >access[] resolve-access
  loop ;

: arg>access >avalue u16@ >access[] ;

: resolve-arg
  dup is-access if
    dup arg>access >tag-addr @ swap >avalue u16!
  then ;

: resolve-instr
  3 0 ?do
    i over >arg[] resolve-arg
  loop
  drop ;

: resolve-instrs
  instr-ct 0 ?do
    i >instr[] resolve-instr
  loop ;

\ === generators

: :generator
  word >number unwrap ,
  word >number unwrap ,
  [compile] : ;

: >arg-ct cfa> unwrap 2 cell - ;
: >byte-ct >arg-ct cell + ;
: >genfn ;

: generator>stk~
  dup >arg-ct @ swap >byte-ct @ ;

( arg-ct -- ...mkempty )
: gen-empty-args 3 swap - 0 ?do mkempty loop ;

0 cell field >generator
  cell field >base
constant idef

: definstr
  create , ,
  does>
    dup >r
      >generator @ generator>stk~
      +to phere gen-empty-args
    r> instr, ;

: idef>stk dup >generator @ swap >base @ ;

\ note generators are evaluated with ( instr base )
: ieval ( instr -- )
  dup
  >idef @ idef>stk ( instr generator base )
  swap execute ;

\ === passes

: pass1 resolve-accesses resolve-instrs ;

: pass2
  instr-ct 0 ?do
    i >instr[] ieval
  loop ;

: assemble pass1 pass2 ;

\ ===

: >arg[]@ >arg[] >avalue u16@ ;

32 k u16s mkarray progmem program

\ : opc, program arrayu16, ;
: opc, ;

:generator 0 2 ~base opc, drop ;
:generator 3 2 ~byte
  over 0 >arg[]@  0x1 and 8 lshift or
  over 1 >arg[]@  0x1 and 9 lshift or
  swap 2 >arg[]@ 0xff and          or
  opc, ;
:generator 2 2 ~byte-a
  over 0 >arg[]@  0x1 and 8 lshift or
  swap 1 >arg[]@ 0xff and          or
  opc, ;
:generator 3 2 ~bit
  over 0 >arg[]@  0x7 and 8 lshift or
  over 1 >arg[]@  0x1 and 9 lshift or
  swap 2 >arg[]@ 0xff and          or
  opc, ;

' ~base 0x00000000 definstr nop,
' ~base 0x0000ffff definstr reset,

\ === helpers

\ : a$ word access, abs, ;
\ : r$ word access, rel, ;

\ addwf, 255 arg, word label access, mkabs arg, mkempty arg,
