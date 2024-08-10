defmodule Benplusplus.Parser do
  import Benplusplus.Lexer
  import Benplusplus.Node

  @precedence [
    :value,
    :add_sub,
    :multiply_divide,
    :expression
  ]

  defp higher_precedence(precedence_level) do
    case precedence_level do
      :value -> error("No higher precedence level than value")
      :add_sub -> :value
      :multiply_divide -> :add_sub
      :expression -> :multiply_divide
    end
  end

  def parse(token_stream) do
    IO.puts("Parsing compound")
    statementList = parse_compound(token_stream)

    case statementList do
      :nil -> error("Expected statement in code passed")
      _ ->
        #[emptyHopefully | statementList] = statementList
        #IO.puts("Extracted hopefully empty: #{prettyprint(emptyHopefully)}")
        Benplusplus.Node.construct_node(:program, statementList)
    end
  end

  def pp_statement_list(root) do
    case root do
      :nil -> ":nil"
      [] -> ""
      [head | tail] -> "#{prettyprint(head)}, #{pp_statement_list(tail)}"
    end
  end

  def prettyprint(root) do
    # {:number, number()} |
    # {:binop, astnode(), astnode(), char()} |
    # {:var, String.t() } |
    # # type node, identifier, then expression
    # {:vardecl, astnode(), astnode(), astnode() } |
    # # left var then expression
    # {:assign, astnode(), astnode() } |
    # {:program, list()} |
    # {:type, atom()}

    case root do
      {:number, value} -> "<Number: #{value}>"
      {:binop, left, right, char} -> "<Binop, op: #{char}, LHS: #{prettyprint(left)}, RHS: #{prettyprint(right)}>"
      {:var, name} -> "<Var: #{name}>"
      {:vardecl, type, identifier, expression} -> "<Declaration(#{prettyprint(type)}): var: #{prettyprint(identifier)}, val: #{prettyprint(expression)}>"
      {:assign, var, rhs} -> "<Assign, var: #{prettyprint(var)}, val: #{prettyprint(rhs)}>"
      {:program, nodes} -> "<Program, values: [#{pp_statement_list(nodes)}]>"
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
        {node, token_stream} = statement(token_stream)
        [ node | parse_compound(token_stream)]
    end
  end

  defp statement(token_stream) do
    [current_token | token_stream] = token_stream

    case current_token do
      {:identifier, value} ->
        var_node = Benplusplus.Node.construct_node(:var, value)

        token_stream = expect(token_stream, :assignment)
        [_ | token_stream] = token_stream

        case token_stream do
          [] -> error("Expected type or expression after assignment")
          [{token_type, token_value} | token_stream] ->
            case token_type do
              :int ->
                token_stream = expect(token_stream, :assignment)
                [_ | token_stream] = token_stream
                {rhs, token_stream} = expression(token_stream, :expression)
                { Benplusplus.Node.construct_node(:vardecl, var_node, Benplusplus.Node.construct_node(:type, :int), rhs), token_stream }
              # Construct assignment
              _ ->
                token_stream = [{token_type, token_value} | token_stream]
                IO.puts("Current stream: #{Benplusplus.Lexer.pretty_print(token_stream)}")
                {rhs, token_stream} = expression(token_stream, :expression)
                IO.puts("Got expression: #{prettyprint(rhs)}")
                { Benplusplus.Node.construct_node(:assign, var_node, rhs), token_stream }
            end
        end
      _ -> error("Expected identifier when parsing statement")
    end
  end

  defp precedence_value(token_stream) do
    current_token = hd(token_stream)

    case current_token do
      {:number, value} ->
        IO.inspect(tl(token_stream), label: "Constructing value node")
        { Benplusplus.Node.construct_node(:number, String.to_integer(value)), tl(token_stream) }
      {:identifier, value} ->
        { Benplusplus.Node.construct_node(:var, value), tl(token_stream) }
      _ -> raise("Expected number or variable in parser, got: #{elem(current_token, 0)}")
    end
  end

  def expression(token_stream, :value) do
    precedence_value(token_stream)
  end

  def expression(token_stream, precedence_level) do
    { lhs, token_stream } = expression(token_stream, higher_precedence(precedence_level))

    case token_stream do
      [] -> { lhs, token_stream }
      [{op_type, op_value} | token_stream] ->
        case precedence_level do
          :add_sub ->
            cond do
              op_type in [:plus, :minus] ->
                { rhs, token_stream } = expression(token_stream, higher_precedence(precedence_level))
                { Benplusplus.Node.construct_node(:binop, lhs, rhs, op_type), token_stream }
              # Add back operator
              true -> { lhs, [{op_type, op_value} | token_stream] }
            end
          :multiply_divide ->
            cond do
              op_type in [:multiply, :divide] ->
                { rhs, token_stream } = expression(token_stream, higher_precedence(precedence_level))
                { Benplusplus.Node.construct_node(:binop, lhs, rhs, op_type), token_stream }
              # Add back operator
              true -> { lhs, [{op_type, op_value} | token_stream] }
            end
          :expression -> { lhs, token_stream }
        end
      _ -> raise("Token stream bad")
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
