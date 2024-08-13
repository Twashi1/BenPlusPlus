defmodule Benplusplus.Codegenerator do
  defmodule Context do
    defstruct stack_frames: []
  end

  defmodule StackFrame do
    # Including arena pointer to track how much memory of the stack we've allocated so far
    defstruct size: 0, variable_mapping: %{}, arena_pointer: 0
  end

  defp error(message) do
    IO.puts("Generator error: #{message}")
    :error
  end

  # Stack of stack frames
  # On each stack frame, store mapping of variables to their offset from the stack pointer
  # Store a current stack offset so we can deal with temporaries in each scope

  def generate_code(ast_node, context) do
    case ast_node do
      {:number, number} -> generate_code_number(number, context)
      {:binop, left, right, op_atom} -> generate_code_binop(left, right, op_atom, context)
      {:compound, statement_list, stack_size} -> generate_code_compound(statement_list, stack_size, context)
      {:assign, var, expression} -> generate_code_assign(var, expression, context)
      {:vardecl, type, var, expression} -> generate_code_variable_declaration(type, var, expression, context)
      {:var, var_name} -> generate_code_variable(var_name, context)
      _ -> {["Unknown: #{Benplusplus.Parser.prettyprint(ast_node)}"], :nil}
    end
  end

  defp generate_statement_list(statement_list, context) do
    case statement_list do
      [] -> {[], context}
      [head | tail] ->
        {current_code, context} = generate_code(head, context)
        {tail_code, final_context} = generate_statement_list(tail, context)

        {current_code ++ tail_code, final_context}
    end
  end

  defp generate_stack_frame(statement_list, current_stack_frame) do
    case statement_list do
      [] -> current_stack_frame
      [head | tail] ->
        # TODO: do proper visits for both type and var
        case head do
          {:vardecl, type, var, _expr} ->
            new_stack_frame = %StackFrame{current_stack_frame |
              arena_pointer: current_stack_frame.arena_pointer + Benplusplus.Node.sizeof_type(elem(type, 1)),
              variable_mapping: Map.put(current_stack_frame.variable_mapping, elem(var, 1), current_stack_frame.arena_pointer)
            }

            generate_stack_frame(tail, new_stack_frame)
          _ -> generate_stack_frame(tail, current_stack_frame)
        end
    end
  end

  defp generate_code_variable(var_name, context) do
    # Load variable into register t0, and push to temporary stack
    # (Context not modified)
    {read_var_code, _context} = read_variable(var_name, context)
    {write_var_stack, context} = write_to_stack(context)

    {read_var_code ++ write_var_stack, context}
  end

  defp generate_code_compound(statement_list, stack_size, context) do
    # Generate stack for size of stack
    stack_create = "addi sp, sp, -#{stack_size}"
    # Generate context
    stack_frame = generate_stack_frame(statement_list, %StackFrame{size: stack_size})

    new_context = %Context{stack_frames: [stack_frame | context.stack_frames]}

    # Context modifications should only be on the new stack frame
    # so we keep the old context in our return
    {statements, _context} = generate_statement_list(statement_list, new_context)

    # Destroy stack
    stack_destroy = "addi sp, sp, #{stack_size}"

    # Keeping old context in our return
    {[stack_create] ++ statements ++ [stack_destroy], context}
  end

  defp generate_code_assign(var, expression, context) do
    # Calculate value of expression and push to arena_pointer stack
    {expr_code, context} = generate_code(expression, context)
    # Load into t0
    {read_expr, context} = read_from_stack(context)
    # Save to variable
    # TODO: visit var node properly to get name
    {save_var, context} = write_variable(elem(var, 1), context)

    {expr_code ++ read_expr ++ save_var, context}
  end

  # Just a regular assignment call, we could do semantic analysis here with type, but everythings an integer right now
  defp generate_code_variable_declaration(_type, var, expression, context) do
    generate_code_assign(var, expression, context)
  end

  defp modify_arena_context(diff, context) do
    # Pop off lowest frame
    [current_frame | tail_frames] = context.stack_frames

    if current_frame.arena_pointer + diff > current_frame.size or current_frame.arena_pointer + diff < 0 do
      error("Ran out of space on stack, had space: #{current_frame.size}")
    end

    # "Modify" current frame's arena pointer
    new_frame = %StackFrame{current_frame | arena_pointer: current_frame.arena_pointer + diff}
    # Add new frame back and return
    %Context{stack_frames: [new_frame | tail_frames]}
  end

  # Get location of variable taking into account current stack frames
  # Returns :nil if variable not found
  defp get_variable_location(var_name, stack_frames, start_offset \\ 0) do
    IO.inspect(stack_frames, label: "Looking for variable #{var_name} in context")

    case stack_frames do
      [] -> :nil
      [head | tail] ->
        # Look in current stack frame
        case Map.fetch(head.variable_mapping, var_name) do
          {:ok, value} ->
            start_offset + value
          :error -> get_variable_location(var_name, tail, head.size)
        end
    end
  end

  # Reads variable into register t0
  defp read_variable(var_name, context) do
    var_location = get_variable_location(var_name, context.stack_frames)

    case var_location do
      :nil -> error("Couldn't find variable #{var_name} in context")
      _ -> {["lw t0, #{var_location}(sp)"], context}
    end
  end

  # Write value from register t0 into variable
  defp write_variable(var_name, context) do
    var_location = get_variable_location(var_name, context.stack_frames)

    case var_location do
      :nil -> error("Couldn't find variable #{var_name} in context")
      _ -> {["sw t0, #{var_location}(sp)"], context}
    end
  end

  # Write value of register t0 to stack
  defp write_to_stack(context) do
    current_frame = hd(context.stack_frames)

    {["sw t0, #{current_frame.arena_pointer}(sp)"], modify_arena_context(4, context)}
  end

  defp read_from_stack(context) do
    context = modify_arena_context(-4, context)
    current_frame = hd(context.stack_frames)

    {["lw t0, #{current_frame.arena_pointer}(sp)"], context}
  end

  defp generate_code_number(number, context) do
    # Load number into register t0 and save to stack
    load_number = ["addi t0, zero, #{number}"]
    {load_to_stack, context} = write_to_stack(context)

    {load_number ++ load_to_stack, context}
  end

  defp generate_code_binop(left, right, op_atom, context) do
    # Push two numbers to stack
    {left_code, context} = generate_code(left, context)
    {right_code, context} = generate_code(right, context)

    operation_code = case op_atom do
      :plus -> "add t0, t0, t1"
      :minus -> "sub t0, t0, t1"
      :multiply -> "mul t0, t0, t1"
      :divide -> "div t0, t0, t1"
      _ -> raise("Expected mathematical operator +-*/, got #{op_atom}")
    end

    {read_left_value, context} = read_from_stack(context)
    {read_right_value, context} = read_from_stack(context)
    {write_result, context} = write_to_stack(context)

    # Calculate left value (and saves to stack)
    # Calculate right value (and saves to stack)
    # Read left from stack and move to register t1
    # Read right from stack into register t0
    # Perform operation
    # Write back to stack
    {left_code ++ right_code ++ read_left_value ++ ["mv t1, t0"] ++ read_right_value ++ [operation_code] ++ write_result, context}
  end
end
