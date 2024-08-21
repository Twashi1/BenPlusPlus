## Core
- Parser cleanup, use more `parse_xxx` functions to organise code
  - Use `parse_type` where applicable
- Semantic analysis
  - Check variables aren't being redeclared
  - Checking size required for each scope
- Stop using `mv` and various other pseudo-instructions where possible
- Using excessive stack memory, each statement should be counted for required stack space, and then we simply
    take the maximum of all statements in a statement list
- Function arguments are not working perfectly:
  - Calculation of arguments takes place inside the callee's stack, instead of the caller, thus variables in the callee that share the same name as
    parameters in the caller are not evaluted correctly

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