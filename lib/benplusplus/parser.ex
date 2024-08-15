defmodule Benplusplus.Parser do
  """
  Current definition:

  <program> ::= <statement_list>
  <compound> ::= [ <statement_list> ]
  <statement_list> ::= <statement> | <statement> <statement_list>
  <statement> ::= <declaration> | <assignment>
  <declaration> ::= <identifier> == <type> == <expression> :
  <assignment> ::= <identifier> == <expression> :
  <type> ::= int
  <expression> ::= <number> | <expression> <operation> <expression> | {<expression>}
  <operation> ::= + | - | / | *
  """


  @type precedence() :: :value | :add_sub | :multiply_divide | :expression

  @spec error(String.t()) :: no_return()
  defp error(message) do
    raise RuntimeError, message: "Parser error: #{message}"
  end

  @spec higher_precedence(precedence()) :: precedence()
  defp higher_precedence(precedence_level) do
    case precedence_level do
      :add_sub -> :value
      :multiply_divide -> :add_sub
      :expression -> :multiply_divide
    end
  end

  @spec parse(list(Benplusplus.Lexer.token())) :: Benplusplus.Node.node_compound()
  def parse(token_stream) do
    parse_compound(token_stream)
  end

  @spec pretty_print_statements(list(Benplusplus.Node.astnode())) :: String.t()
  def pretty_print_statements(statements) do
    case statements do
      :nil -> ":nil"
      [] -> ""
      [head | tail] -> "#{pretty_print_node(head)}, #{pretty_print_statements(tail)}"
    end
  end

  @spec pretty_print_node(Benplusplus.Node.astnode()) :: String.t()
  def pretty_print_node(root) do
    case root do
      {:number, value} -> "<Number: #{value}>"
      {:binop, left, right, char} -> "<Binop, op: #{char}, LHS: #{pretty_print_node(left)}, RHS: #{pretty_print_node(right)}>"
      {:var, name} -> "<Var: #{name}>"
      {:vardecl, type, identifier, expression} -> "<Declaration(#{pretty_print_node(type)}): var: #{pretty_print_node(identifier)}, val: #{pretty_print_node(expression)}>"
      {:assign, var, rhs} -> "<Assign, var: #{pretty_print_node(var)}, val: #{pretty_print_node(rhs)}>"
      {:compound, nodes, stack_size} -> "<Compound(size:#{stack_size}), values: [#{pretty_print_statements(nodes)}]>"
      {:type, atom} -> "<Type: #{Atom.to_string(atom)}>"
      _ ->
        IO.inspect(root, label: "Got unknown token type")
        "<Unknown?>"
    end
  end

  @spec parse_compound(list(Benplusplus.Lexer.token())) :: Benplusplus.Node.node_compound()
  defp parse_compound(token_stream) do
    {statements, stack_size} = statement_list(token_stream)

    Benplusplus.Node.construct_compound(statements, stack_size)
  end

  @spec statement_list(list(Benplusplus.Lexer.token())) :: {list(Benplusplus.Node.astnode()), integer()}
  defp statement_list(token_stream) do
    case token_stream do
      [] -> {[], 0}
      _ ->
        {node, token_stream, stack_required} = statement(token_stream)
        token_stream = eat(token_stream, :colon)

        case token_stream do
          [] -> { [node], stack_required }
          _ ->
            { tail_statements, tail_stack } = statement_list(token_stream)
            { [node | tail_statements], tail_stack + stack_required }
        end
    end
  end

  @spec statement(list(Benplusplus.Lexer.token())) :: {Benplusplus.Node.astnode(), list(Benplusplus.Lexer.token()), integer()}
  defp statement(token_stream) do
    [current_token | token_stream] = token_stream

    case current_token do
      {:identifier, value} ->
        var_node = Benplusplus.Node.construct_variable(value)

        # Eat assignment token
        token_stream = eat(token_stream, :assignment)

        case token_stream do
          [] -> error("Expected type or expression after assignment")
          [{token_type, token_value} | token_stream] ->
            case token_type do
              # Construct variable declaration
              :int ->
                IO.puts("Parsing variable declaration for token stream: #{Benplusplus.Lexer.pretty_print_tokens(token_stream)}")
                token_stream = eat(token_stream, :assignment)
                {rhs, token_stream, additional_stack } = expression(token_stream, :expression)
                IO.puts("Ate all characters, left with: #{Benplusplus.Lexer.pretty_print_tokens(token_stream)}")
                { Benplusplus.Node.construct_variable_declaration(Benplusplus.Node.construct_type(:int), var_node, rhs), token_stream, additional_stack + Benplusplus.Node.sizeof_type(:int) }
              # Construct assignment
              _ ->
                token_stream = [{token_type, token_value} | token_stream]
                IO.puts("Current stream: #{Benplusplus.Lexer.pretty_print_tokens(token_stream)}")
                {rhs, token_stream, additional_stack } = expression(token_stream, :expression)
                IO.puts("Got expression: #{pretty_print_node(rhs)}")
                { Benplusplus.Node.construct_assignment(var_node, rhs), token_stream, additional_stack }
            end
        end
      _ -> error("Expected identifier when parsing statement")
    end
  end

  @spec precedence_value(list(Benplusplus.Lexer.token())) :: {Benplusplus.Node.node_number() | Benplusplus.Node.node_var(), list(Benplusplus.Lexer.token()), integer()}
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
      # Equivalent of parenthesis
      {:left_curly, _value} ->
        # Advance past the left curly
        token_stream = eat(token_stream, :left_curly)
        # Get the inner expression
        { inner, token_stream, stack_required } = expression(token_stream)
        # Advance past the right curly
        token_stream = eat(token_stream, :right_curly)
        # Return inner expression
        { inner, token_stream, stack_required}
      _ -> error("Expected number or variable in parser, got: #{elem(current_token, 0)}")
    end
  end

  @spec expression(list(Benplusplus.Lexer.token())) :: {Benplusplus.Node.astnode(), list(Benplusplus.Lexer.token()), integer()}
  def expression(token_stream) do
    expression(token_stream, :expression)
  end

  @spec expression(list(Benplusplus.Lexer.token()), :value) :: {Benplusplus.Node.astnode(), list(Benplusplus.Lexer.token()), integer()}
  defp expression(token_stream, :value) do
    precedence_value(token_stream)
  end

  @spec expression(list(Benplusplus.Lexer.token()), precedence()) :: {Benplusplus.Node.astnode(), list(Benplusplus.Lexer.token()), integer()}
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
    end
  end

  # Validates the next token in the stream is of a certain type
  @spec eat(list(Benplusplus.Lexer.token()), atom()) :: list(Benplusplus.Lexer.token())
  defp eat(token_stream, token_type) do
    case token_stream do
      [] -> error("Expected token #{token_type} but got end of file")
      [current_token | tail] -> if elem(current_token, 0) == token_type, do: tail, else: error("Expected token #{token_type} got token #{elem(current_token, 0)}")
    end
  end
end
