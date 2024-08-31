: Ks 1024 * ;
: short 2 chars ;
: shorts short * ;
: short! ( val addr -- ) over 8 rshift over c! 1+ c! ;

create pmem 32 Ks shorts allot
0 value phere

\ todo opcodes should be aligned
\      assume they are and just make sure  raw data put in progmem is aligned
: opcode, ( opc -- )
  pmem phere + short!
  1 shorts +to phere ;

: pmem-base-addr 0x0000 ;

create eeprom 512 chars allot
0 value eeprom-here

create config 10 chars allot
0 value config-mask

: config, ( val n -- )
  9 over - 1 swap lshift
  config-mask or to config-mask
  config + c! ;

\ === labels

\ todo could use a linked list for labels,
\      accesses i think you need a list? maybe not
32 constant label-max-chars
label-max-chars chars constant label-max-len
512 constant accesses-ct
512 constant labels-ct

: move-label-str ( src dest len -- )
  label-max-chars min chars move ;

0 cell          field >access-is-rel?
  label-max-len field >access-name
  cell          field >access-name-len
constant access

create accesses access accesses-ct * allot
0 value ahere

: access! ( name namelen is-rel? addr -- )
  tuck >access-is-rel? !
  2dup >access-name-len !
       >access-name swap move-label-str ;

: access,
  accesses ahere + access!
  access +to ahere ;

0 cell          field >label-addr
  label-max-len field >label-name
  cell          field >label-name-len
constant label

create labels label labels-ct * allot
0 value lhere

: label! ( name namelen pmem-addr addr -- )
  tuck >label-addr !
  2dup >label-name-len !
       >label-name swap move-label-str ;

: label,
  labels lhere + label!
  label +to lhere ;

: find-label ( name name-len -- addr )
  2drop 0
  ;

\ ===

: :generator
  word >number unwrap ,
  word >number unwrap ,
  [compile] : ;

: >arg-ct cfa> unwrap 2 cells - ;
: >byte-ct cfa> unwrap 1 cells - ;

: >ud ;
: >generator cell + ;
: idef> dup >ud @ swap >generator @ ;

: fill-args ( ct -- x... )
  3 swap ?do 0 loop ;

0 cell field >is-instruction
  cell field >arg1
  cell field >arg2
  cell field >arg3
  cell field >idef
constant item

create items 32 Ks item * allot
0 value ihere
0 value phere-prepass

: inst! ( a1 a2 a3 idef addr -- )
  true over >is-instruction !
  tuck >idef !
  tuck >arg3 !
  tuck >arg2 !
       >arg1 ! ;

: inst,
  items ihere + inst!
  item +to ihere ;

: inst> ( addr -- a1 a2 a3 idef )
  dup >arg1 @ swap
  dup >arg2 @ swap
  dup >arg3 @ swap
      >idef @ ;

: addr! ( val addr -- )
  false over >is-instruction !
  >arg1 ! ;

: addr,
  items ihere + addr!
  item +to ihere ;

: addr> >arg1 @ ;

: instruction
  create , ,
  does>
    dup >r
    >generator @ >arg-ct @ fill-args r@ inst,
    r> >generator @ >byte-ct @ +to phere-prepass
    ;

: eval-inst ( addr -- new-phere )
  inst> idef> ( a1 a2 a3 ud generator )
  execute
  \ todo use byte ct to move phere
  phere
  ;

: eval-addr ( addr -- new-phere )
  addr> ;

: ieval ( addr -- )
  dup >is-instruction @
  if eval-inst else eval-addr then
  to phere ;

\ === processing

\ first pass
\   resolve label accesses by going through arguments of every instruction
\   find labels for each access by natching name in label list
\   resolve abs + rel accesses based on label location

\ second pass
\   all args are updated
\   run through and 'ieval' each instruction
\   opcodes will be generated, phere (2nd pass) is used

: arg-is-access?
  0x10000 and 0= 0= ;

: arg>access ( val -- addr )
  0xFFFF and access * accesses + ;

: access>label
  dup >access-name swap >access-name-len find-label ;

: process-abs-rel ( curr-phere label-paddr t/f-is-relative? -- paddr)
  \ todo make sure math is right
  >access-is-rel? if swap - else nip then ;

: resolve-access ( curr-phere arg -- paddr )
  arg>access
  dup access>label >label-addr ( curr-phere access label-paddr )
  swap >access-is-rel? process-abs-rel ;

\ TODO
\ maybe notify when an aceess is detected so you dont get errors
: first-pass
  \ TODO
  0 0 ?do
    i resolve-access
  loop ;

\ ===

: $abs
  ahere 0x10000 or
  word false access, ;

: $rel
  ahere 0x10000 or
  word true access, ;

: $label ( "name" -- )
  word pmem-base-addr phere-prepass + label, ;

: @here ( addr -- )
  dup addr, to phere-prepass ;

\ ===

:generator 0 2 do-nothing
  opcode, 3drop ;

:generator 3 2 byte-oriented
  >r
  0x1  and 8 lshift -rot
  0x1  and 9 lshift -rot
  0xff and
  r>
  or or or opcode, ;

:generator 2 2 byte-oriented-a
  >r
  drop
  0x1  and 8 lshift swap
  0xff and
  r>
  or or opcode, ;

:generator 3 2 bit-oriented
  >r
  0x7  and 8 lshift -rot
  0x1  and 9 lshift -rot
  0xff and
  r>
  or or or opcode, ;

:generator 2 2 fsr-inst
  >r
  drop
  0x3f and          swap
  0x3  and 6 lshift
  r>
  or or opcode, ;

: mask ( a1 a2 a3 ud mask -- opc )
  >r >r 2drop r> swap r> and or ;

:generator 1 2 literal-inst 0xff mask opcode, ;
:generator 1 2 control-11   0x7ff mask opcode, ;
:generator 1 2 control-8    0xff mask opcode, ;
:generator 1 2 return-inst  0x1 mask opcode, ;

:generator 2 4 _movff,
  2drop
  0xfff and swap 0b1100000000000000 or opcode,
  0xfff and      0b1111000000000000 or opcode, ;

:generator 2 6 _movffl,
  2drop
  \ todo cleanup
  over 10 rshift             0b0000000001100000 or opcode,
  tuck 12 rshift
  swap 0x3ff and 2 lshift or 0b1111000000000000 or opcode,
  0xfff and                  0b1111000000000000 or opcode, ;

\ ===

\                   ++++||||++++||||
' byte-oriented   0b0010010000000000 instruction addwf,
' byte-oriented   0b0010000000000000 instruction addwfc,
' byte-oriented   0b0001010000000000 instruction andwf,
' byte-oriented-a 0b0110101000000000 instruction clrf,
' byte-oriented   0b0001110000000000 instruction comf,
' byte-oriented   0b0000010000000000 instruction decf,
' byte-oriented   0b0010100000000000 instruction incf,
' byte-oriented   0b0001000000000000 instruction iorwf,
' byte-oriented   0b0101000000000000 instruction movf,
' _movff,         0                  instruction movff,
' _movffl,        0                  instruction movff,
' byte-oriented-a 0b0110111000000000 instruction movwf,
' byte-oriented-a 0b0000001000000000 instruction mulwf,
' byte-oriented-a 0b0110110000000000 instruction negf,
' byte-oriented   0b0011010000000000 instruction rlcf,
' byte-oriented   0b0100010000000000 instruction rlncf,
' byte-oriented   0b0011000000000000 instruction rrcf,
' byte-oriented   0b0100000000000000 instruction rrncf,
' byte-oriented-a 0b0110100000000000 instruction setf,
' byte-oriented   0b0101010000000000 instruction subfwb,
' byte-oriented   0b0101110000000000 instruction subwf,
' byte-oriented   0b0101100000000000 instruction subwfb,
' byte-oriented   0b0011100000000000 instruction swapf,
' byte-oriented   0b0001100000000000 instruction xorf,
' byte-oriented-a 0b0110001000000000 instruction cpfseq,
' byte-oriented-a 0b0110010000000000 instruction cpfsgt,
' byte-oriented-a 0b0110000000000000 instruction cpfslt,
' byte-oriented   0b0010110000000000 instruction decfsz,
' byte-oriented   0b0100110000000000 instruction dcfsnz,
' byte-oriented   0b0011110000000000 instruction incfsz,
' byte-oriented   0b0100100000000000 instruction infsnz,
' byte-oriented-a 0b0110011000000000 instruction tstfsz,
' bit-oriented    0b1001000000000000 instruction bcf,
' bit-oriented    0b1000000000000000 instruction bsf,
' bit-oriented    0b0111000000000000 instruction btg,
' bit-oriented    0b1011000000000000 instruction btfc,
' bit-oriented    0b1010000000000000 instruction btfss,
' control-8       0b1110001000000000 instruction bc,
' control-8       0b1110011000000000 instruction bn,
' control-8       0b1110001100000000 instruction bnc,
' control-8       0b1110011100000000 instruction bnn,
' control-8       0b1110010100000000 instruction bnov,
' control-8       0b1110000100000000 instruction bnz,
' control-8       0b1110010000000000 instruction bov,
' control-11      0b1101000000000000 instruction bra,
' control-8       0b1110000000000000 instruction bz,
\ : call,
\ : callw,
\ : goto,
' control-11      0b1101100000000000 instruction rcall,
' return-inst     0b0000000000010000 instruction retfie,
' control-8       0b0000110000000000 instruction retlw,
' return-inst     0b0000000000010010 instruction return,
' do-nothing      0b0000000000000100 instruction clrwdt,
' do-nothing      0b0000000000000111 instruction daw,
' do-nothing      0b0000000000000000 instruction nop,
' do-nothing      0b0000000000000110 instruction pop,
' do-nothing      0b0000000000000101 instruction push,
' do-nothing      0b0000000011111111 instruction reset,
' do-nothing      0b0000000000000011 instruction sleep,
' fsr-inst        0b1110100000000000 instruction addfsr,
' literal-inst    0b0000111100000000 instruction addlw,
' literal-inst    0b0000101100000000 instruction andlw,
' literal-inst    0b0000100100000000 instruction iorlw,
\ : lfsr
\ : movlb,   ( k -- )     0x3f and        b< 0000 0001 00__ ____ or opcode, ;
' literal-inst    0b0000111000000000 instruction movlw,
' literal-inst    0b0000110100000000 instruction mullw,
' literal-inst    0b0000110000000000 instruction retlw,
' fsr-inst        0b1110100100000000 instruction subfsr,
' literal-inst    0b0000100000000000 instruction sublw,
' literal-inst    0b0000101000000000 instruction xorlw,
' do-nothing      0b0000000000001000 instruction tblrd*,
' do-nothing      0b0000000000001001 instruction tblrd*+,
' do-nothing      0b0000000000001010 instruction tblrd*-,
' do-nothing      0b0000000000001011 instruction tblrd+*,
' do-nothing      0b0000000000001100 instruction tblwt*,
' do-nothing      0b0000000000001101 instruction tblwt*+,
' do-nothing      0b0000000000001110 instruction tblwt*-,
' do-nothing      0b0000000000001111 instruction tblwt+*,

\ ====

0xbeef @here
$label resets
nop, nop,
nop, nop,
nop, nop,
nop, nop,
nop, nop,
nop, nop,
nop, nop,
nop, nop,
nop, nop,

0x0080 @here
$label prog-start

1 $abs label 3 addwf,

\ items ieval
\ items 64 cells dump
\ labels 64 cells dump
