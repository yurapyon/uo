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

\ === generators

: :generator
  word >number unwrap ,
  word >number unwrap ,
  [compile] : ;

: >arg-ct cfa> unwrap 2 cell - ;
: >byte-ct >arg-ct cell + ;

: generator, dup >byte-ct @ iheader, ;
: consume-args 0 ?do arg, loop ;

: >generator ;
: >base cell + ;

: idef
  create , ,
  does>
    >generator @
    dup generator,
        >arg-ct @ consume-args ;

: idef>stk dup @ swap >base @ ;

: ieval ( instr -- )
  dup
  >idef @ idef>stk ( instr generator base )
  -rot execute ;

:generator 0 2 ~nop drop opc, ;

' ~nop 0x00000000 idef nop,
' ~nop 0x0000ffff idef nop,

\ :idef 0x0000 1   nop, do-nothing ;
\ :idef 0xffff 1 reset, do-nothing ;

\ === helpers

: a$ word access, abs, ;
: r$ word access, rel, ;

\ : addwf, ['] _addwf 1 instr, ;
\ addwf, 255 arg, word label access, mkabs arg, mkempty arg,

( x

create pmem 32 k u16s allot
pmem value phere

0x0000 constant pbase

: pw,
  phere u16!
  u16 +to phere ;

  )

