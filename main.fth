\ note
\ this code isn't very memory efficient

: advance-here ( ct -- previous-here )
  here @ swap allot align ;

: copy, ( addr addr-len -- )
  advance-here
  swap move ;

: save, ( addr addr-len -- new-addr addr-len )
  here @ -rot
  2dup copy,
  nip ;

\ ===

: short 2 chars ;
: shorts short * ;
: short! ( val addr -- )
  over 8 rshift over c! 1+ c! ;

create progmem 32 1024 * shorts allot
0 value progmem-here

\ NOTE
\   opcodes should be short aligned
\   assume they are and make sure any rawdata added to progmem is aligned
: opcode, ( opcode -- )
  progmem progmem-here + short!
  1 shorts +to progmem-here ;

: progmem-base-addr 0x0000 ;

\ TODO
\ eeprom
\ config

\ =====

\ instruction memory

create imem 32 1024 * cells allot
imem value imem-here

: i, ( value -- )
  imem-here !
  cell +to imem-here ;

\ =====

0 cell field >code-object-type
constant code-object-header

  0 enum %instruction
    enum %address-tag
constant %label

: code-object-header, i, ;

\ =====

0x10000 flag ^access
    constant ^empty

: flag-is-set and 0= 0= ;

cell constant argument
: argument-value 0xffff and ;
: argument-is-access ^access flag-is-set ;
: argyment-is-empty  ^empty flag-is-set ;

code-object-header
                  \ >code-object-type
 argument 3 * field >instruction-args
         cell field >instruction-definition
constant instruction

: instruction3, ( idef arg0 arg1 arg2 -- )
  %instruction code-object-header,
  flip i, i, i, i, ;

: instruction2, ( idef arg0 arg1 -- )
  ^empty instruction3, ;

: instruction1, ( idef arg0 -- )
  ^empty instruction2, ;

: instruction0, ( idef -- )
  ^empty instruction1, ;

code-object-header
           \ >code-object-type
  cell field >address-tag-address
constant address-tag

: address-tag, ( address -- )
  %address-tag code-object-header,
  i, ;

code-object-header
           \ >code-object-type
  cell field >label-name-ptr
  cell field >label-name-len
  cell field >label-address
constant label

: label, ( name-ptr name-len -- )
  save,
  %label code-object-header,
  swap i,
  i,
  0 i, ;

\ ===

0 cell field >access-name-ptr
  cell field >access-name-len
  cell field >access-is-absolute
  cell field >access-address
constant access

create accesses 512 access * allot
accesses value access-here

: a, ( value -- )
  access-here !
  cell +to access-here ;

: access, ( name-ptr name-len is-absolute -- )
  -rot
  save
  swap a,
  a,
  a,
  0 a, ;

: $a
  access-count ^access or
  \ todo
  \ word true access,
  ;

: $r
  access-count ^access or
  \ word false access,
  ;


\ to avoid multipass,
\ labels can resolve past accesses
\ like 'realtime linking'

\ an access can just tag itself as needing to be resolved

\ how does this handle local/scoped labels? ie for loops

( _
\ multipass assembler

\ first pass
\   resolve label accesses
\     resolve absolute/relative accesses

\ second pass
\   args will be updated
\     generate opcodes for each arg
)

: label ( "name" -- )
  progmem-here
  [compile] constant ;

label $this-is-a-label

$this-is-a-label .

100 +to progmem-here

label $this-is-a-label-2

$this-is-a-label .
$this-is-a-label-2 .
