: mkspc ( ct -- previous-here )
  here @ swap allot align ;

: save, ( addr addr-len -- new-addr addr-len )
  tuck
  here @ swap move
  dup mkspc swap ;

: k 1024 * ;

: u16 2 chars ;
: u16s u16 * ;
: u16! ( value addr -- )
  over 8 rshift over 1+ c! c! ;

\ ===

: >type ;
char constant etype

\ instruction types
  0 enum %instr
    enum %addr
constant %label

\ argument types
  0 enum %empty
    enum %abs
constant %rel

\ ===

etype      \ >type
   u16 field >avalue
constant arg

etype       \ >type
arg 3 * field >args
   cell field >idef
constant instr

etype      \ >type
  cell field >tag-addr
constant addr

etype      \ >type
  cell field >label-name
  cell field >label-len
  cell field >label-addr
constant label

\ ===

: arg-cell ( type value -- arg-cell )
  swap 16 lshift or ;

: is-empty >etype c@ %empty = ;
: is-abs   >etype c@ %abs = ;
: is-rel   >etype c@ %rel = ;

: mkempty %empty 0 arg-cell ;
: mkabs  %abs swap arg-cell ;
: mkrel  %rel swap arg-cell ;

create imem 32 k instr allot
imem value ihere

: i, ( value -- )
  ihere !
  cell +to ihere ;

: ic,
  ihere c!
  char +to ihere ;

: iu16,
  ihere u16!
  u16 +to ihere ;

: etype, ic, ;

: arg, ( arg-cell -- )
  dup 16 rshift etype, iu16, ;

: instr3, ( definition arg arg arg -- )
  %instr etype,
  arg, arg, arg, i, ;

: instr2, mkempty instr3, ;
: instr1, mkempty instr2, ;
: instr0, mkempty instr1, ;

: addr, ( address -- )
  %addr etype, i, ;

: label,
  save,
  %label etype,
  swap i, i, 0 i, ;

( x

create pmem 32 k u16s allot
pmem value phere

0x0000 constant pbase

: pw,
  phere u16!
  u16 +to phere ;

  )

