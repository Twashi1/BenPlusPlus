defmodule Benplusplus.Parser do
  defp higher_precedence(precedence_level) do
    case precedence_level do
      :add_sub -> :value
      :multiply_divide -> :add_sub
      :expression -> :multiply_divide
    end
  end

  def parse(token_stream) do
    IO.puts("Parsing compound")
    { statementList, stack_size } = parse_compound(token_stream)

    Benplusplus.Node.construct_compound(statementList, stack_size)
  end

  def pp_statement_list(root) do
    case root do
      :nil -> ":nil"
      [] -> ""
      [head | tail] -> "#{prettyprint(head)}, #{pp_statement_list(tail)}"
    end
  end

  def prettyprint(root) do
    case root do
      {:number, value} -> "<Number: #{value}>"
      {:binop, left, right, char} -> "<Binop, op: #{char}, LHS: #{prettyprint(left)}, RHS: #{prettyprint(right)}>"
      {:var, name} -> "<Var: #{name}>"
      {:vardecl, type, identifier, expression} -> "<Declaration(#{prettyprint(type)}): var: #{prettyprint(identifier)}, val: #{prettyprint(expression)}>"
      {:assign, var, rhs} -> "<Assign, var: #{prettyprint(var)}, val: #{prettyprint(rhs)}>"
      {:compound, nodes, stack_size} -> "<Compound(size:#{stack_size}), values: [#{pp_statement_list(nodes)}]>"
      {:type, atom} -> "<Type: #{Atom.to_string(atom)}>"
      _ ->
        IO.inspect(root, label: "Got unknown token type")
        "<Unknown?>"
    end
  end

  def parse_compound(token_stream) do
    IO.puts("Currently parsing stream: #{Benplusplus.Lexer.pretty_print(token_stream)}")
    case token_stream do
      [] -> :nil
      _ ->
        {node, token_stream, stack_required} = statement(token_stream)
        expect(token_stream, :colon)
        [_colonToken | token_stream] = token_stream

        case token_stream do
          [] -> { [node], stack_required }
          _ ->
            { tail_statements, tail_stack } = parse_compound(token_stream)
            { [node | tail_statements], tail_stack + stack_required }
        end
    end
  end

  defp statement(token_stream) do
    [current_token | token_stream] = token_stream

    case current_token do
      {:identifier, value} ->
        var_node = Benplusplus.Node.construct_variable(value)

        token_stream = expect(token_stream, :assignment)
        [_ | token_stream] = token_stream

        case token_stream do
          [] -> error("Expected type or expression after assignment")
          [{token_type, token_value} | token_stream] ->
            case token_type do
              # Construct variable declaration
              :int ->
                IO.puts("Parsing variable declaration for token stream: #{Benplusplus.Lexer.pretty_print(token_stream)}")
                token_stream = expect(token_stream, :assignment)
                [_ | token_stream] = token_stream
                {rhs, token_stream, additional_stack } = expression(token_stream, :expression)
                IO.puts("Ate all characters, left with: #{Benplusplus.Lexer.pretty_print(token_stream)}")
                { Benplusplus.Node.construct_variable_declaration(Benplusplus.Node.construct_type(:int), var_node, rhs), token_stream, additional_stack + Benplusplus.Node.sizeof_type(:int) }
              # Construct assignment
              _ ->
                token_stream = [{token_type, token_value} | token_stream]
                IO.puts("Current stream: #{Benplusplus.Lexer.pretty_print(token_stream)}")
                {rhs, token_stream, additional_stack } = expression(token_stream, :expression)
                IO.puts("Got expression: #{prettyprint(rhs)}")
                { Benplusplus.Node.construct_assignment(var_node, rhs), token_stream, additional_stack }
            end
        end
      _ -> error("Expected identifier when parsing statement")
    end
  end

  defp precedence_value(token_stream) do
    current_token = hd(token_stream)

    case current_token do
      {:number, value} ->
        IO.inspect(token_stream, label: "Constructing value node")
        { Benplusplus.Node.construct_number(String.to_integer(value)), tl(token_stream), Benplusplus.Node.sizeof_type(:int) }
      {:identifier, value} ->
        # TODO: require space for this right now, but not ideal (we need space on arena pointer for temporary)
        #   could only really fix in code generator
        { Benplusplus.Node.construct_variable(value), tl(token_stream), Benplusplus.Node.sizeof_type(:int) }
      _ -> error("Expected number or variable in parser, got: #{elem(current_token, 0)}")
    end
  end

  def expression(token_stream) do
    expression(token_stream, :expression)
  end

  defp expression(token_stream, :value) do
    precedence_value(token_stream)
  end

  defp expression(token_stream, precedence_level) do
    { lhs, token_stream, stack_required } = expression(token_stream, higher_precedence(precedence_level))

    case token_stream do
      [] -> { lhs, token_stream }
      [{op_type, op_value} | token_stream] ->
        case precedence_level do
          :add_sub ->
            cond do
              op_type in [:plus, :minus] ->
                { rhs, token_stream, additional_stack } = expression(token_stream, higher_precedence(precedence_level))
                { Benplusplus.Node.construct_binary_operation(lhs, rhs, op_type), token_stream, stack_required + additional_stack }
              # Add back operator
              true -> { lhs, [{op_type, op_value} | token_stream], stack_required }
            end
          :multiply_divide ->
            cond do
              op_type in [:multiply, :divide] ->
                { rhs, token_stream, additional_stack } = expression(token_stream, higher_precedence(precedence_level))
                { Benplusplus.Node.construct_binary_operation(lhs, rhs, op_type), token_stream, stack_required + additional_stack }
              # Add back operator
              true -> { lhs, [{op_type, op_value} | token_stream], stack_required }
            end
          :expression ->
            { lhs, [{op_type, op_value} | token_stream], stack_required }
        end
      _ -> error("Bad token stream")
    end
  end

  defp error(message) do
    IO.puts("Parser error: #{message}")
    :error
  end

  defp expect(token_stream, token_type) do
    case token_stream do
      [] -> error("Expected token #{token_type} but got end of file")
      [current_token | tail] -> if elem(current_token, 0) == token_type, do: [current_token | tail], else: error("Expected token #{token_type} got token #{elem(current_token, 0)}")
    end
  end
end
