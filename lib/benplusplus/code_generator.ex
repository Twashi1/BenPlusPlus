defmodule Benplusplus.Codegenerator do
  defmodule Context do
    defstruct stack_frames: []
  end

  # Stack of stack frames
  # On each stack frame, store mapping of variables to their offset from the stack pointer
  # Also store a mapping of variables to their type (Node.type_atoms())
  # Store a current stack offset so we can deal with temporaries in each scope
  defmodule StackFrame do
    # Including arena pointer to track how much memory of the stack we've allocated so far
    defstruct size: 0, variable_mapping: %{}, arena_pointer: 0, var_type_mapping: %{}
  end

  @spec error(String.t()) :: no_return()
  defp error(message) do
    raise RuntimeError, message: "Generator error: #{message}"
  end

  @spec generate_code(Benplusplus.Node.astnode(), %Context{}) :: {list(String.t()), %Context{}}
  def generate_code(ast_node, context) do
    case ast_node do
      {:number, number} -> generate_code_number(number, context)
      {:binop, left, right, op_atom} -> generate_code_binop(left, right, op_atom, context)
      {:unary, value, op_atom} -> generate_code_unary(value, op_atom, context)
      {:compound, statement_list} -> generate_code_compound(statement_list, context)
      {:assign, var, expression} -> generate_code_assign(var, expression, context)
      {:vardecl, type, var, expression} -> generate_code_variable_declaration(type, var, expression, context)
      {:var, var_name} -> generate_code_variable(var_name, context)
      {:boolean, value} -> generate_code_bool(value, context)
      _ -> {["Unknown: #{Benplusplus.Parser.pretty_print_node(ast_node)}"], context}
    end
  end

  @spec generate_instructions(Benplusplus.Node.astnode()) :: list(String.t())
  def generate_instructions(ast_node) do
    {instructions, _context} = generate_code(ast_node, %Context{})

    instructions
  end

  @spec generate_statement_list(list(Benplusplus.Node.astnode()), %Context{}) :: {list(String.t()), %Context{}}
  defp generate_statement_list(statement_list, context) do
    case statement_list do
      [] -> {[], context}
      [head | tail] ->
        {current_code, context} = generate_code(head, context)
        {tail_code, final_context} = generate_statement_list(tail, context)

        {current_code ++ tail_code, final_context}
    end
  end

  @spec find_variable_type(String.t(), list(%StackFrame{})) :: :nil | Benplusplus.Node.type_atoms()
  defp find_variable_type(var_name, stack_frames) do
    case stack_frames do
      [] -> :nil
      [head | tail] ->
        # Look in current stack frame
        case Map.fetch(head.var_type_mapping, var_name) do
          {:ok, value} ->
            value
          :error -> find_variable_type(var_name, tail)
        end
    end
  end

  @spec count_stack_size(Benplusplus.Node.astnode(), list(%StackFrame{})) :: integer()
  defp count_stack_size(root, stack_frames) do
    case root do
      {:number, _value} -> Benplusplus.Node.sizeof_type(:int)
      {:boolean, _value} -> Benplusplus.Node.sizeof_type(:bool)
      {:binop, left, right, _op_atom} ->
        count_stack_size(left, stack_frames) + count_stack_size(right, stack_frames)
      {:unary, value, _op_atom} ->
        count_stack_size(value, stack_frames)
      {:var, var_name} ->
        case find_variable_type(var_name, stack_frames) do
          :nil -> error("Unrecognised variable #{var_name}")
          type -> Benplusplus.Node.sizeof_type(type)
        end
      _ ->
        error("Got invalid node when counting stack size: #{Benplusplus.Parser.pretty_print_node(root)}")
    end
  end

  @spec generate_stack_frame(list(Benplusplus.Node.astnode()), %Context{}, %StackFrame{}) :: %StackFrame{}
  defp generate_stack_frame(statement_list, context, current_stack_frame) do
    case statement_list do
      [] -> current_stack_frame
      [head | tail] ->
        # TODO: do proper visits for both type and var
        result_frame = case head do
          {:vardecl, type, var, expr} ->
            # Add variable declaration itself to stack
            current_stack_frame = %StackFrame{current_stack_frame |
              size: current_stack_frame.size + Benplusplus.Node.sizeof_type(elem(type, 1)),
              arena_pointer: current_stack_frame.arena_pointer + Benplusplus.Node.sizeof_type(elem(type, 1)),
              variable_mapping: Map.put(current_stack_frame.variable_mapping, elem(var, 1), current_stack_frame.arena_pointer),
              var_type_mapping: Map.put(current_stack_frame.var_type_mapping, elem(var, 1), elem(type, 1))
            }

            # Count size of expression
            %StackFrame{current_stack_frame |
              size: current_stack_frame.size + count_stack_size(expr, [current_stack_frame | context.stack_frames])
            }
          {:assign, _var, expr} ->
            # Count size of expression
            %StackFrame{current_stack_frame |
              size: current_stack_frame.size + count_stack_size(expr, [current_stack_frame | context.stack_frames])
            }
          _ -> current_stack_frame
        end

        generate_stack_frame(tail, context, result_frame)
    end
  end

  @spec generate_code_bool(:true | :false, %Context{}) :: {list(String.t()), %Context{}}
  defp generate_code_bool(truthiness, context) do
    statement = case truthiness do
      :true -> ["addi t0, zero, -1"]
      :false -> ["addi t0, zero, 0"]
    end

    {write_stack, context} = write_to_stack(context)

    {statement ++ write_stack, context}
  end

  @spec generate_code_variable(String.t(), %Context{}) :: {list(String.t()), %Context{}}
  defp generate_code_variable(var_name, context) do
    # Load variable into register t0, and push to temporary stack
    # (Context not modified)
    {read_var_code, _context} = read_variable(var_name, context)
    {write_var_stack, context} = write_to_stack(context)

    {read_var_code ++ write_var_stack, context}
  end

  @spec generate_code_compound(list(Benplusplus.Node.astnode()), %Context{}) :: {list(String.t()), %Context{}}
  defp generate_code_compound(statement_list, context) do
    # Generate context
    stack_frame = generate_stack_frame(statement_list, context, %StackFrame{size: 0})

    # Generate stack for size of stack
    stack_create = "addi sp, sp, -#{stack_frame.size}"

    new_context = %Context{stack_frames: [stack_frame | context.stack_frames]}

    # Context modifications should only be on the new stack frame
    # so we keep the old context in our return
    {statements, _context} = generate_statement_list(statement_list, new_context)

    # Destroy stack
    stack_destroy = ["addi sp, sp, #{stack_frame.size}"]

    # Keeping old context in our return
    {[stack_create | statements] ++ stack_destroy, context}
  end

  @spec generate_code_assign(Benplusplus.Node.node_var(), Benplusplus.Node.astnode(), %Context{}) :: {list(String.t()), %Context{}}
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
  @spec generate_code_variable_declaration(Benplusplus.Node.node_type(), Benplusplus.Node.node_var(), Benplusplus.Node.astnode(), %Context{}) :: {list(String.t()), %Context{}}
  defp generate_code_variable_declaration(_type, var, expression, context) do
    generate_code_assign(var, expression, context)
  end

  @spec generate_code_number(integer(), %Context{}) :: {list(String.t()), %Context{}}
  defp generate_code_number(number, context) do
    # Load number into register t0 and save to stack
    load_number = "addi t0, zero, #{number}"
    {load_to_stack, context} = write_to_stack(context)

    {[load_number | load_to_stack], context}
  end

  @spec generate_code_binop(Benplusplus.Node.astnode(), Benplusplus.Node.astnode(), Benplusplus.Node.op_atoms(), %Context{}) :: {list(String.t()), %Context{}}
  defp generate_code_binop(left, right, op_atom, context) do
    # Push two numbers to stack
    {left_code, context} = generate_code(left, context)
    {right_code, context} = generate_code(right, context)

    operation_code = case op_atom do
      :plus -> ["add t0, t0, t1"]
      :minus -> ["sub t0, t0, t1"]
      :multiply -> ["mul t0, t0, t1"]
      :divide -> ["div t0, t0, t1"]
      :equal -> ["xor t0, t0, t1", "xori t0, t0, -1"]
      :and -> ["and t0, t0, t1"]
      :or -> ["or t0, t0, t1"]
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
    {left_code ++ right_code ++ read_left_value ++ ["mv t1, t0"] ++ read_right_value ++ operation_code ++ write_result, context}
  end

  @spec generate_code_unary(Benplusplus.Node.astnode(), Benplusplus.Node.unary_op_atoms(), %Context{}) :: {list(String.t()), %Context{}}
  defp generate_code_unary(value, op_atom, context) do
    # Push value to stack
    {value_code, context} = generate_code(value, context)

    operation_code = case op_atom do
      :minus -> ["sub t0, zero, t0"]
      :not -> ["xori t0, t0, -1"]
    end

    # Load value to t0
    {read_value, context} = read_from_stack(context)
    {write_result, context} = write_to_stack(context)

    {value_code ++ read_value ++ operation_code ++ write_result, context}
  end

  # Move the arena pointer of the first stack frame by diff
  @spec modify_arena_context(integer(), %Context{}) :: %Context{}
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
  @spec get_variable_location(String.t(), list(%StackFrame{}), integer()) :: :nil | integer()
  defp get_variable_location(var_name, stack_frames, start_offset \\ 0) do
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
  @spec read_variable(String.t(), %Context{}) :: {list(String.t()), %Context{}}
  defp read_variable(var_name, context) do
    var_location = get_variable_location(var_name, context.stack_frames)

    case var_location do
      :nil -> error("Couldn't find variable #{var_name} in context")
      _ -> {["lw t0, #{var_location}(sp)"], context}
    end
  end

  # Write value from register t0 into variable
  @spec write_variable(String.t(), %Context{}) :: {list(String.t()), %Context{}}
  defp write_variable(var_name, context) do
    var_location = get_variable_location(var_name, context.stack_frames)

    case var_location do
      :nil -> error("Couldn't find variable #{var_name} in context")
      _ -> {["sw t0, #{var_location}(sp)"], context}
    end
  end

  # Write value of register t0 to stack
  @spec write_to_stack(%Context{}) :: {list(String.t()), %Context{}}
  defp write_to_stack(context) do
    current_frame = hd(context.stack_frames)

    {["sw t0, #{current_frame.arena_pointer}(sp)"], modify_arena_context(4, context)}
  end

  @spec read_from_stack(%Context{}) :: {list(String.t()), %Context{}}
  defp read_from_stack(context) do
    context = modify_arena_context(-4, context)
    current_frame = hd(context.stack_frames)

    {["lw t0, #{current_frame.arena_pointer}(sp)"], context}
  end
end
