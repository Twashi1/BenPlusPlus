defmodule Benplusplus.Codegenerator do
  # Stores the current stack frames accessible, and the next available label id
  defmodule Context do
    defstruct scopes: [], label_id: 0
  end

  defmodule VarSymbol do
    defstruct location: 0, type: :nil
  end

  defmodule Scope do
    defstruct stack_size: 0, arena_pointer: 0, variable_map: %{}, function_map: %{}
  end

  defmodule FunctionSymbol do
    defstruct assigned_label: 0, scope: %Scope{}, return_type: :nil, parameter_order: []
  end

  @spec error(String.t()) :: no_return()
  defp error(message) do
    raise RuntimeError, message: "Generator error: #{message}"
  end

  @spec get_variable_symbol(String.t(), [%Scope{}]) :: :nil | %VarSymbol{}
  defp get_variable_symbol(name, scopes) do
    case scopes do
      [] -> :nil
      [scope | tail] ->
        case scope.variable_map[name] do
          :nil -> get_variable_symbol(name, tail)
          symbol -> symbol
        end
    end
  end

  @spec get_function_symbol(String.t(), [%Scope{}]) :: :nil | %FunctionSymbol{}
  defp get_function_symbol(name, scopes) do
    case scopes do
      [] -> :nil
      [scope | tail] ->
        case scope.function_map[name] do
          :nil -> get_function_symbol(name, tail)
          symbol -> symbol
        end
    end
  end

  @spec increment_label(%Context{}) :: %Context{}
  defp increment_label(context) do
    %Context{context | label_id: context.label_id + 1}
  end

  # Only modifies the label id of the context
  @spec create_scope([Benplusplus.Node.astnode()], %Context{}, %Scope{}) :: {%Scope{}, %Context{}}
  defp create_scope(statements, context, current_scope) do
    case statements do
      [] -> {current_scope, context}
      [statement | tail] ->
        {current_scope, context} = case statement do
          {:compound, _statements} -> {current_scope, context}
          {:noop} -> {current_scope, context}
          {:number, _number} ->
            size = Benplusplus.Node.sizeof_type(:int)

            {%Scope{current_scope | stack_size: current_scope.stack_size + size}, context}
          {:boolean, _value} ->
            size = Benplusplus.Node.sizeof_type(:bool)

            {%Scope{current_scope | stack_size: current_scope.stack_size + size}, context}
          {:binop, left, right, _op_atom} ->
            create_scope([left, right], context, current_scope)
          {:unary, value, _op_atom} ->
            create_scope([value], context, current_scope)
          {:if, condition, success_branch, failure_branch} ->
            create_scope([condition, success_branch, failure_branch], context, current_scope)
          {:while, condition, body} ->
            create_scope([condition, body], context, current_scope)
          {:funccall, name, _arguments} ->
            case get_function_symbol(name, [current_scope | context.scopes]) do
              :nil -> error("Couldn't find function #{name}")
              symbol ->
                size = Benplusplus.Node.sizeof_type(symbol.return_type)

                {%Scope{current_scope | stack_size: current_scope.stack_size + size}, context}
            end
          {:var, var_name} ->
            case get_variable_symbol(var_name, [current_scope | context.scopes]) do
              :nil -> error("Couldn't find variable #{var_name}")
              symbol ->
                size = Benplusplus.Node.sizeof_type(symbol.type)

                {%Scope{current_scope | stack_size: current_scope.stack_size + size}, context}
            end
          {:vardecl, type, var, expr} ->
            {:var, name} = var
            {:type, type_atom} = type

            case get_variable_symbol(name, [current_scope | context.scopes]) do
              :nil ->
                size = Benplusplus.Node.sizeof_type(type_atom)

                current_scope = %Scope{current_scope | stack_size: current_scope.stack_size + size, arena_pointer: current_scope.arena_pointer + size,
                  variable_map: Map.put(current_scope.variable_map, name,
                    %VarSymbol{location: current_scope.arena_pointer, type: type_atom}
                  )
                }

                create_scope([expr], context, current_scope)
              _ -> error("Variable #{name} already declared")
            end
          {:assign, var, expr} ->
            {:var, name} = var

            case get_variable_symbol(name, [current_scope | context.scopes]) do
              :nil -> error("Variable #{name} has not been declared")
              _ -> create_scope([expr], context, current_scope)
            end
          {:funcdecl, name, parameters, type, _body} ->
            case get_function_symbol(name, [current_scope | context.scopes]) do
              :nil ->
                {:type, type_atom} = type

                # TODO: unresolved stack causes issues that require extra memory
                # Reserve space for special variable at 0(sp)
                internal_scope = allocate_parameters_in_scope(parameters, %Scope{stack_size: 4, arena_pointer: 4})

                {%Scope{current_scope | function_map: Map.put(current_scope.function_map, name, %FunctionSymbol{
                  assigned_label: context.label_id, scope: internal_scope, return_type: type_atom,
                  parameter_order: Enum.map(parameters, fn {:parameter, {:var, name}, _type} -> name end)
                })}, increment_label(context)}
              _ -> error("Function #{name} has already been declared")
            end
        end

        create_scope(tail, context, current_scope)
    end
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
      {:if, condition, success_branch, failure_branch} -> generate_code_if(condition, success_branch, failure_branch, context)
      {:funcdecl, name, parameters, type, code} -> generate_code_funcdecl(name, parameters, code, type, context)
      {:funccall, name, arguments} -> generate_code_funccall(name, arguments, context)
      {:while, condition, body} -> generate_code_while(condition, body, context)
      {:noop} -> {[], context}
      _ -> {["# Unrecognised/Invalid node: #{Benplusplus.Parser.pretty_print_node(ast_node)}"], context}
    end
  end

  @spec generate_instructions(Benplusplus.Node.astnode()) :: list(String.t())
  def generate_instructions(ast_node) do
    {instructions, _context} = generate_code(ast_node, %Context{})

    instructions
  end

  @spec generate_statement_list([Benplusplus.Node.astnode()], %Context{}) :: {[String.t()], %Context{}}
  defp generate_statement_list(statement_list, context) do
    case statement_list do
      [] -> {[], context}
      [head | tail] ->
        {current_code, context} = generate_code(head, context)
        {tail_code, context} = generate_statement_list(tail, context)

        {current_code ++ tail_code, context}
    end
  end

  @spec allocate_parameters_in_scope([Benplusplus.Node.node_parameter()], %Scope{}) :: %Scope{}
  defp allocate_parameters_in_scope(parameters, scope) do
    case parameters do
      [] -> scope
      [head | tail] ->
        {:parameter, var, type} = head
        {:var, name} = var
        {:type, type_atom} = type

        size = Benplusplus.Node.sizeof_type(type_atom)

        # Multiply size by 2 to accomodate extra space for loading parameters
        scope = %Scope{scope |
          stack_size: scope.stack_size + size * 2,
          arena_pointer: scope.arena_pointer + size,
          variable_map: Map.put(scope.variable_map, name, %VarSymbol{location: scope.arena_pointer, type: type_atom}),
        }

        allocate_parameters_in_scope(tail, scope)
    end
  end

  # On a function call
  # Create scope for function
  # Generate code for each parameter (relying on variable referencing working outside of scope!)
  # Each parameter in on stack of function where expected
  # Now move each parameter to correct variable slot
  # Now enter function call (headless compound)
  # Destroy scope for function

  defp generate_code_arguments(arguments, parameters, context) do
    case arguments do
      [] -> {[], context}
      [argument | tail] ->
        # Generate code for argument and put on function stack
        {argument_code, context} = generate_code(argument, context)
        # Read argument from stack, and write to variable in our current scope
        {read_argument, context} = read_from_stack(context)
        # Add variables back into this context
        {write_argument, context} = write_variable(hd(parameters), context)

        {load_other_arguments, context} = generate_code_arguments(tail, tl(parameters), context)

        {argument_code ++ read_argument ++ write_argument ++ load_other_arguments, context}
    end
  end

  @spec generate_code_funccall(String.t(), list(Benplusplus.Node.astnode()), %Context{}) :: {list(String.t()), %Context{}}
  defp generate_code_funccall(name, arguments, context) do
    # Search function call
    function_symbol = case get_function_symbol(name, context.scopes) do
      :nil -> error("Failed to find function name: #{name}")
      function_symbol -> function_symbol
    end

    # Get the function scope
    function_scope = function_symbol.scope
    # For each argument, load
    {generated_code, function_context} = generate_code_arguments(arguments, function_symbol.parameter_order, %Context{context | scopes: [function_scope | context.scopes]})
    # Create/destroy stack
    create_stack = ["addi sp, sp, -#{function_scope.stack_size}"]
    destroy_stack = ["addi sp, sp, #{function_scope.stack_size}"]
    # Jump
    jalr = ["jal ra, fn#{function_symbol.assigned_label}start"]

    context = %Context{context | label_id: function_context.label_id}

    {get_return_value, context} = write_to_stack(context)

    {create_stack ++ generated_code ++ jalr ++ destroy_stack ++ get_return_value, context}
  end

  defp generate_code_funcdecl(name, _parameters, body, _return_type, context) do
    # Stack has already been created
    function_symbol = case get_function_symbol(name, context.scopes) do
      :nil -> error("Failed to find function name: #{name}")
      function_symbol -> function_symbol
    end

    # Save return address to 0(sp)
    write_return = ["sw ra, 0(sp)"]
    # Generate statements
    {:compound, body_statements} = body
    {function_scope, context} = create_scope(body_statements, context, function_symbol.scope)
    function_context = %Context{context | scopes: [function_scope | context.scopes]}
    {statements_code, function_context} = generate_statement_list(body_statements, function_context)
    # Load return address into ra
    load_return = ["lw ra, 0(sp)"]
    # Jump to return address
    jump_return = ["jalr zero, 0(ra)"]

    skip_function = ["jal zero, fn#{function_symbol.assigned_label}end"]
    start_label = ["fn#{function_symbol.assigned_label}start:"]
    end_label = ["fn#{function_symbol.assigned_label}end:"]

    context = %Context{context | label_id: function_context.label_id}

    {skip_function ++ start_label ++ write_return ++ statements_code ++ load_return ++ jump_return ++ end_label, context}
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

  @spec generate_code_while(Benplusplus.Node.astnode(), Benplusplus.Node.astnode(), %Context{}) :: {list(String.t()), %Context{}}
  defp generate_code_while(condition, body, context) do
    start_label = "while#{context.label_id}start"
    end_label = "while#{context.label_id}end"
    context = increment_label(context)

    {condition_code, context} = generate_code(condition, context)
    {read_condition, context} = read_from_stack(context)

    {body_code, body_context} = generate_code(body, context)
    context = %Context{context | label_id: body_context.label_id}

    {["#{start_label}:"] ++ condition_code ++ read_condition ++ ["slti t0, t0, t1", "beq t0, zero, #{end_label}"] ++ body_code ++ ["beq zero, zero, #{start_label}"] ++ ["#{end_label}:"], context}
  end

  @spec generate_code_if(Benplusplus.Node.astnode(), Benplusplus.Node.astnode(), Benplusplus.Node.astnode(), %Context{}) :: {list(String.t()), %Context{}}
  defp generate_code_if(condition, success_branch, failure_branch, context) do
    # Expecting to get out some expression, maybe validate this?
    positive_label = "if#{context.label_id}p"
    negative_label = "if#{context.label_id}n"
    end_label = "if#{context.label_id}end"
    context = increment_label(context)

    {condition_code, context} = generate_code(condition, context)
    {read_condition, context} = read_from_stack(context)

    {success_branch, body_context} = generate_code(success_branch, context)
    context = %Context{context | label_id: body_context.label_id}
    {failure_branch, body_context} = generate_code(failure_branch, context)
    context = %Context{context | label_id: body_context.label_id}

    {condition_code ++ read_condition ++ ["slti t0, t0, 1"] ++ ["bne t0, zero, #{positive_label}"] ++ ["#{negative_label}:"] ++ failure_branch ++ ["beq zero, zero, #{end_label}"] ++ ["#{positive_label}:"] ++ success_branch ++ ["#{end_label}:"], context}
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
    generate_code_compound(statement_list, context, %Scope{})
  end

  @spec generate_code_compound(list(Benplusplus.Node.astnode()), %Context{}, %Scope{}) :: {list(String.t()), %Context{}}
  defp generate_code_compound(statement_list, context, seed_scope) do
    # Generate context
    {scope, context} = create_scope(statement_list, context, seed_scope)

    # Generate stack for size of stack
    stack_create = "addi sp, sp, -#{scope.stack_size}"

    compound_context = %Context{context | scopes: [scope | context.scopes]}

    # Context modifications should only be on the new stack frame
    # so we keep the old context in our return
    {statements, compound_context} = generate_statement_list(statement_list, compound_context)

    # Destroy stack
    stack_destroy = ["addi sp, sp, #{scope.stack_size}"]

    context = %Context{context | label_id: compound_context.label_id}

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
      :equal -> ["xor t0, t0, t1", "slti t0, t0, 1"]
      :less_than -> ["slt t0, t0, t1"]
      :more_than -> ["slt t0, t1, t0"]
      :more_eq -> ["slt t0, t0, t1", "slti t0, t0, 1"]
      :less_eq -> ["slt t0, t1, t0", "slti t0, t0, 1"]
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
      :not -> ["slti t0, t0, 1"]
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
    [current_frame | tail_frames] = context.scopes

    if current_frame.arena_pointer + diff > current_frame.stack_size or current_frame.arena_pointer + diff < 0 do
      IO.inspect(context, label: "Failed context")
      error("Ran out of space on stack, had space: #{current_frame.stack_size}")
    end

    # "Modify" current frame's arena pointer
    new_frame = %Scope{current_frame | arena_pointer: current_frame.arena_pointer + diff}
    # Add new frame back and return
    %Context{context | scopes: [new_frame | tail_frames]}
  end

  # Get location of variable, throws if it can't find it
  @spec get_variable_location(String.t(), list(%Scope{}), integer()) :: integer()
  defp get_variable_location(var_name, scopes, start_offset \\ 0) do
    case scopes do
      [] -> error("Couldn't find variable #{var_name}'s location")
      [head | tail] ->
        # Look in current stack frame
        case Map.fetch(head.variable_map, var_name) do
          {:ok, symbol} ->
            start_offset + symbol.location
          :error -> get_variable_location(var_name, tail, head.stack_size)
        end
    end
  end

  # Reads variable into register t0
  @spec read_variable(String.t(), %Context{}) :: {list(String.t()), %Context{}}
  defp read_variable(var_name, context) do
    var_location = get_variable_location(var_name, context.scopes)

    {["lw t0, #{var_location}(sp)"], context}
  end

  # Write value from register t0 into variable
  @spec write_variable(String.t(), %Context{}) :: {list(String.t()), %Context{}}
  defp write_variable(var_name, context) do
    var_location = get_variable_location(var_name, context.scopes)

    {["sw t0, #{var_location}(sp)"], context}
  end

  # Write value of register t0 to stack
  @spec write_to_stack(%Context{}) :: {list(String.t()), %Context{}}
  defp write_to_stack(context) do
    current_frame = hd(context.scopes)

    {["sw t0, #{current_frame.arena_pointer}(sp)"], modify_arena_context(4, context)}
  end

  @spec read_from_stack(%Context{}) :: {list(String.t()), %Context{}}
  defp read_from_stack(context) do
    context = modify_arena_context(-4, context)
    current_frame = hd(context.scopes)

    {["lw t0, #{current_frame.arena_pointer}(sp)"], context}
  end
end
