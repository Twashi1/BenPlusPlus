## Core
- Parser cleanup, use more `parse_xxx` functions to organise code
  - Use `parse_type` where applicable
- Semantic analysis
  - Check variables aren't being redeclared
  - Checking size required for each scope
- Stop using `mv` and various other pseudo-instructions where possible
- Fix requirement for excess stack memory in function declaration, or at least formalise it
  - Extraneous memory usage might be linked to expressions which aren't released from arena when out of use?
- Don't save to `ra`, instead save to `0(sp)` and modify all function scopes to account for that special address

## Language features
- Output?
- Data types
  - Floats
    - Requires large changes, many places where assumptions are made that all types are 4-byte integers (`modify_arena_context`, various loads/stores)
  - Strings
    - String literals
    - String comparison
    - String indexing
  - Lists
    - Indexing
- Loops
  - While loop
  - For range loop (syntatic sugar, just a while loop)
- Clear function returns

## Large/aspirational features
- Compile to intermediary that can be easily optimised (ignore redundant move/load/store)
  - With such a format, we could also likely reduce the amount of stack, currently it tends to overestimate space required (only in function declarations now?)
  - Return value optimisation should also come basically free with this change
- Heap allocation
- Structs