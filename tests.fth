true value run-tests

: test(
  word
  run-tests if
    cr
    ." test: " type cr
  else
    2drop
    begin word s" )test" string= until
  then
; immediate

: )test ; immediate

include uo.fth

test( utils
:noname
  hex
  here @ . 10 mkspc here @ - . cr
  here @ . s" string" save, type space here @ . cr
  0xdeadbeef here @ u16! here @ u16@ . cr
  decimal
  ;
execute
)test

test( arrays
8 mkarray _tmem _tarray

:noname
  _tmem _tarray .s cr drop drop
  _tarray array>stk .s cr drop drop
  _tarray array>stk .s cr drop drop
  0xdeadbeef _tarray arrayu16,
  _tarray u16 array-ct . cr
  _tarray >array-mem @ 8 u16s dump
  hex
  _tarray array>stk .s cr cell mod . cr drop
  _tarray cell align-array
  _tarray array>stk .s cr cell mod . cr drop
  decimal
  ;
execute
)test

test( args
." arg size: " arg . cr
:noname
  mkempty . cr
  hex
  0xbeef mkabs dup from-acell .s cr drop drop drop
  decimal
  ;
execute
)test

test( tags
create t1 tag allot
create t2 tag allot

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

test( instrs
." instr size: " instr . cr
0 to phere
0xbeef 2 iheader,
    10 mklit arg,
     mkempty arg,
0xbeef mkabs arg,
ifinish,

0x1000 to phere
0xbee5 2 iheader,
    10 mklit arg,
     mkempty arg,
0xbee5 mkabs arg,
ifinish,

0xdede 2 iheader,
    10 mklit arg,
     mkempty arg,
0xdede mkabs arg,
ifinish,

hex
phere . cr
decimal

imem 4 instr * dump
)test

test( tag-arrays
10 tag * mkarray _tmem _tarray

:noname
  s" tag1" 0 _tarray tag,
  s" tag2" 0 _tarray tag,
  0 _tarray >tag[] tag>string type cr
  1 _tarray >tag[] tag>string type cr
  ;
execute
)test

test( resolving
:noname
  0xdead to phere
  s" label" label,
  0xbeef to phere
  s" label2" label,
  s" label" access,
  label-ct . cr
  access-ct . cr
  hex
  0 >access[] access>label
  unwrap'access>label >tag-addr @ .s cr
  decimal
  ;
execute
)test

test( exit bye )test
