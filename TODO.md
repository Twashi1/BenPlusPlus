## Core

## Language features
- Data types
  - Floats
    - Requires large changes, many places where assumptions are made that all types are 4-byte integers
  - Strings
    - String literals (already done?)
    - String comparison
    - String indexing
  - Lists
    - Indexing
- Loops
  - While loop
  - For range loop (syntatic sugar, just a while loop) 
- Functions
  - Procedures
  - Parameters
  - Return values

## Large/aspirational features
- Compile to intermediary that can be easily optimised (ignore redundant move/load/store)
  - With such a format, we could also likely reduce the amount of stack, currently it tends to overestimate space required
  - Return value optimisation should also come basically free with this change
- Heap allocation
- Structs