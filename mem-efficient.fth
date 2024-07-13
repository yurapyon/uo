: mkspc ( ct -- previous-here )
  here @ swap allot align ;

: save, ( addr addr-len -- new-addr addr-len )
  tuck
  here @ swap move
  dup mkspc swap ;

: is-set and 0= 0= ;

: k 1024 * ;

: u16 2 chars ;
: u16s u16 * ;
: u16! ( value addr -- )
  over 8 rshift over 1+ c! c! ;

create pmem 32 k u16s allot
pmem value phere

0x0000 constant pbase

: pw, ( u16 -- )
  phere u16!
  u16 +to phere ;

\ ===

0 char field >type
constant header

  0 enum %instr
    enum %addr
constant %label

: header i, ;

\ ===

  1 flag ^access
constant ^empty

0 char field >aflags
   u16 field >avalue
constant arg

: arg-is-access >aflags c@ ^access is-set ;
: arg-is-empty >aflags c@ ^empty is-set ;
: arg-cell ( flags value -- arg-cell )
  swap 16 lshift or ;

: empty-arg
  ^empty 0 arg-cell ;

header      \ >type
arg 3 * field >args
   cell field >idef
constant instr

header     \ >type
  cell field >tag-addr
constant addr

header     \ >type
  cell field >label-name
  cell field >label-len
  cell field >label-addr
constant label

\ ===

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

: arg, ( arg-cell -- )
  dup 16 rshift ic, iu16, ;

: header, ic, ;

: instr3, ( definition arg arg arg -- )
  %instr header,
  arg, arg, arg, i, ;

: instr2, empty-arg instr3, ;
: instr1, empty-arg instr2, ;
: instr0, empty-arg instr1, ;

: addr, %addr header, i, ;

: label,
  save,
  %label header,
  swap i, i, 0 i, ;
