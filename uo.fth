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

0 cell field >array-mem
  cell field >array-here
constant array

: <array> 2dup >array-mem ! array-here ! ;
: adv-array ( array amt -- ) swap >array-here tuck @ + ! ;
: array, ( cell array -- ) tuck >array-here @ ! cell adv-array ;
: arrayc, tuck >array-here @ c! char adv-array ;
: arrayu16, tuck >array-here @ u16! u16 adv-array ;

\ ===

32 k constant icount

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

cell constant instr

create imem icount instr * allot
create instrs array allot
imem instrs <array>

: i, instrs array, ;
: ic, instrs arrayc, ;
: iu16, instrs arrayu16, ;

: arg, from-acell ic, iu16, ;
: instr, ( generator width -- ) +to phere i, ;
: @addr to phere ;

create lmem 1 k tag * allot
create labels array allot
lmem labels <array>
: label, phere labels tag, ;

create amem 1 k tag * allot
create accesses array allot
amem access <array>
: access, 0 accesses tag, ;

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

