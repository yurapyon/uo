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

\ ===

0 cell field >array-mem
  cell field >array-here
constant array

: <array> 2dup >array-mem ! >array-here ! ;
: array>stk dup >array-mem @ swap >array-here @ ;
: array-size array>stk - ;
: array-count swap array-size swap / ;
: adv-array >array-here tuck @ +! ;
\ ( value array -- )
: array,    tuck >array-here @ !   cell swap adv-array ;
: arrayc,   tuck >array-here @ c!  char swap adv-array ;
: arrayu16, tuck >array-here @ u16! u16 swap adv-array ;

: mkarray ( array-size "mem-name" "array-name" -- )
  create here @ allot
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

0 char field >atype
   u16 field >avalue
constant arg

: is-lit   >type c@ %lit = ;
: is-empty >type c@ %empty = ;
: is-abs   >type c@ %abs = ;
: is-rel   >type c@ %rel = ;

: mkempty %empty 0 to-acell ;
: mkabs  %abs swap to-acell ;
: mkrel  %rel swap to-acell ;

: to-acell swap 16 lshift or ;
: from-acell dup 16 rshift swap ;

\ ===

0 cell field >tag-name
  cell field >tag-len
  cell field >tag-addr
constant tag

: <tag> ( name len addr tag-addr -- )
  >r
  r@ >tag-addr !
  save,
  r@ >tag-len !
  r> >tag-name ! ;

: tag, ( name len addr tag-array -- )
  >r
  r@ >array-here @ <tag>
  r> tag adv-array ;

\ ===

0 value phere

0  cell field >idef
3 arg * field >args
constant instr

: >arg[] ( instr ct -- )
  arg * swap >args + ;

icount instr * mkarray imem instrs

: i, instrs array, ;
: ic, instrs arrayc, ;
: iu16, instrs arrayu16, ;

: arg, from-acell ic, iu16, ;
: iheader, +to phere i, ;
: @addr to phere ;

lcount tag * mkarray lmem labels
: label, phere labels tag, ;

acount tag * mkarray amem accesses
: access, 0 accesses tag, ;

: resolve-accesses
  \ todo
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

: ieval ( instr -- )
  dup
  >idef @ idef>stk ( instr generator base )
  swap execute ;

\ === passes

: pass1
  \ todo
  resolve-accesses
  ;

: pass2
  \ todo check this works
  instrs >array-here
  instrs array-count 0 ?do
    dup ieval
    dup instr +
  loop ;

: assemble pass1 pass2 ;

\ ===

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

: a$ word access, abs, ;
: r$ word access, rel, ;

\ addwf, 255 arg, word label access, mkabs arg, mkempty arg,
