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
  0 enum %lit
    enum %empty
    enum %abs
constant %rel

\ ===

etype      \ >type
   u16 field >avalue
constant arg

etype       \ >type
   cell field >idef
arg 3 * field >args
constant instr

etype      \ >type
  cell field >tag-addr
constant addr

etype      \ >type
  cell field >label-name
  cell field >label-len
  cell field >label-addr
constant label

0 cell field >access-name
  cell field >access-len
  cell field >access-addr
constant access

0 char field >byte-ct
  cell field >generator
constant idef

\ ===

: to-acell swap 16 lshift or ;
: from-acell dup 16 rshift swap ;

: is-empty >type c@ %empty = ;
: is-abs   >type c@ %abs = ;
: is-rel   >type c@ %rel = ;

: mkempty %empty 0 to-acell ;
: mkabs  %abs swap to-acell ;
: mkrel  %rel swap to-acell ;

create imem 32 k instr allot
imem value ihere

: i, ihere ! cell +to ihere ;
: ic, ihere c! char +to ihere ;
: iu16, ihere u16! u16 +to ihere ;

: etype, ic, ;

: arg, from-acell swap iu16, ic, ;

: instr, %instr etype, i, ;

: addr, %addr etype, i, ;

: label, ( name len -- )
  save,
  swap %label etype, i, i, 0 i, ;

create accmem 1 k access * allot
accmem value acchere
0 value acc-ct

: acc, acchere ! cell +to acchere ;

: access, ( name len -- access-ct )
  save,
  swap acc, acc, 0 acc,
  acc-ct 1 +to acc-ct ;

: a$ word access, abs, ;
: r$ word access, rel, ;

\ : addwf, _addwf instr, ;
\ addwf, 255 arg, word label access, mkabs arg, mkempty arg,

( x

create pmem 32 k u16s allot
pmem value phere

0x0000 constant pbase

: pw,
  phere u16!
  u16 +to phere ;

  )

