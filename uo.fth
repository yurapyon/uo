false value run-tests

: test(
  run-tests 0= if
    begin word s" )test" string= until
  then
; immediate

: )test ; immediate

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

test(
:noname
  hex
  here @ . 10 mkspc here @ - . cr
  here @ . s" string" save, type space here @ . cr
  0xdeadbeef here @ u16! here @ u16@ . cr
  decimal
  ;
execute
)test

\ ===

0 cell field >array-mem
  cell field >array-here
constant array

: <array> 2dup >array-mem ! >array-here ! ;
: array>stk dup >array-mem @ swap >array-here @ ;
: array-size array>stk swap - ;
: array-ct swap array-size swap / ;
: adv-array swap >array-here +! ;
\ ( value array -- )
: array,    tuck >array-here @ !   cell adv-array ;
: arrayc,   tuck >array-here @ c!     1 adv-array ;
: arrayu16, tuck >array-here @ u16! u16 adv-array ;

: mkarray ( array-size "mem-name" "array-name" -- )
  create here @ swap allot
  create here @ array allot
  <array> ;

test(
8 mkarray _tmem _tarray

:noname
  _tmem _tarray .s cr drop drop
  _tarray array>stk .s cr drop drop
  _tarray array>stk .s cr drop drop
  0xdeadbeef _tarray arrayu16,
  _tarray u16 array-ct . cr
  _tarray >array-mem @ 8 u16s dump
  ;
execute
)test

\ ===

32 k constant icount
1 k constant lcount
1 k constant acount

\ ===

  0 enum %lit
    enum %empty
    enum %abs
constant %rel

0   1 field >atype
  u16 field >avalue
constant arg

: to-acell swap 16 lshift or ;
: from-acell dup 16 rshift swap ;

: is-lit   >atype c@ %lit = ;
: is-empty >atype c@ %empty = ;
: is-abs   >atype c@ %abs = ;
: is-rel   >atype c@ %rel = ;

: mkempty %empty 0 to-acell ;
: mkabs  %abs swap to-acell ;
: mkrel  %rel swap to-acell ;

test(
:noname
  mkempty . cr
  0xbeef mkabs dup from-acell .s cr drop drop drop
  ;
execute
)test

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

create t1 tag allot
create t2 tag allot

test(
:noname
  s" tag1" 0xdeadbeef t1 <tag>
  s" tag1" 0xbeefdead t2 <tag>
  t1 tag>string type cr
  t2 tag>string type cr
  t1 t2 tag~= . cr

  t1 >tag-addr @
  t2 >tag-addr @
  .s cr drop drop
  t1 t2 transfer-addr
  t1 >tag-addr @
  t2 >tag-addr @
  .s cr drop drop
  ;
execute
)test

\ ===

0 value phere

0  cell field >idef
3 arg * field >args
constant instr

: >arg* ( instr ct -- addr )
  arg * swap >args + ;

icount instr * mkarray imem instrs

: instr-ct instrs instr array-ct ;

: i, instrs array, ;
: ic, instrs arrayc, ;
: iu16, instrs arrayu16, ;

: arg, from-acell ic, iu16, ;
: iheader, +to phere i, ;
: @addr to phere ;

lcount tag * mkarray lmem labels
acount tag * mkarray amem accesses

: tag, ( name len addr tag-array -- )
  >r
  r@ >array-here @ <tag>
  r> tag adv-array ;
\ ( idx array -- )
: >tag[] >array-mem @ swap tag * + ;

: label, phere labels tag, ;
: label-ct labels array-ct ;
: >label[] labels >tag[] ;

: access, 0 accesses tag, ;
: access-ct accesses array-ct ;
: >access[] accesses >tag[] ;

\ === resolving

: !access-not-found
  ." access not found: "
  tag>string type cr
  panic ;

: access>label ( access -- label )
  label-ct 0 ?do
    i >label[] 2dup tag~=
    if unloop exit
    then drop else
  loop
  !access-not-found ;

: resolve-access dup access>label transfer-addr ;

: resolve-accesses
  access-ct 0 ?do
    i >access[] resolve-access
  loop ;

: resolve-arg
  ;

: resolve-instr
  ;

: resolve-instrs
  ;

\ === generators

: :generator
  word >number unwrap ,
  word >number unwrap ,
  [compile] : ;

: >arg-ct cfa> unwrap 2 cell - ;
: >byte-ct >arg-ct cell + ;

: generator, dup >byte-ct @ iheader, ;
: args, 0 ?do arg, loop ;

0 cell field >generator
  cell field >base
constant idef

: definstr
  create , ,
  does>
    >generator @
    dup generator,
        >arg-ct @ args, ;

: idef>stk dup >generator @ swap >base @ ;

\ note generators are evaluated with ( instr base )
: ieval ( instr -- )
  dup
  >idef @ idef>stk ( instr generator base )
  swap execute ;

\ === passes

: pass1 resolve-accesses resolve-instrs ;

: pass2
  \ todo check this works
  instrs >array-here @
  instr-ct 0 ?do
    dup ieval
    instr +
  loop ;

: assemble pass1 pass2 ;

\ ===

: >arg[] >arg* >avalue u16@ ;

32 k u16s mkarray progmem program

: opc, program arrayu16, ;

:generator 0 2 ~base opc, drop ;
:generator 3 2 ~byte
  over 0 >arg[]  0x1 and 8 lshift or
  over 1 >arg[]  0x1 and 9 lshift or
  swap 2 >arg[] 0xff and          or
  opc, ;
:generator 2 2 ~byte-a
  over 0 >arg[]  0x1 and 8 lshift or
  swap 1 >arg[] 0xff and          or
  opc, ;
:generator 3 2 ~bit
  over 0 >arg[]  0x7 and 8 lshift or
  over 1 >arg[]  0x1 and 9 lshift or
  swap 2 >arg[] 0xff and          or
  opc, ;

' ~base 0x00000000 definstr nop,
' ~base 0x0000ffff definstr reset,

\ === helpers

\ : a$ word access, abs, ;
\ : r$ word access, rel, ;

\ addwf, 255 arg, word label access, mkabs arg, mkempty arg,

