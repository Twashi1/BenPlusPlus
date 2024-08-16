defmodule Benplusplus.Parser do
  _ = """
  Current definition:

  <program> ::= <statement_list>
  <compound> ::= [ <statement_list> ]
  <statement_list> ::= <statement> | <statement> <statement_list>
  <statement> ::= <declaration> | <assignment>
  <declaration> ::= <identifier> == <type> == <expression> :
  <assignment> ::= <identifier> == <expression> :
  <type> ::= int | bool
  <expression> ::= <number> | <identifier> | <expression> <operation> <expression> | {<expression>}
  <operation> ::= + | - | / | * | = | & | \| |
  """
  @typenames %{"int" => :int, "string" => :string, "bool" => :bool, "char" => :char}

  @type precedence() :: :value | :equal | :and | :or | :not | :add_sub | :multiply_divide | :expression

  @spec error(String.t()) :: no_return()
  defp error(message) do
    raise RuntimeError, message: "Parser error: #{message}"
  end

  @spec higher_precedence(precedence()) :: precedence()
  defp higher_precedence(precedence_level) do
    case precedence_level do
      :equal -> :value
      :and -> :equal
      :or -> :and
      :not -> :or
      :add_sub -> :not
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
      [] -> ""
      [head | tail] ->
        case tail do
          [] -> "#{pretty_print_node(head)}"
          _ -> "#{pretty_print_node(head)}, #{pretty_print_statements(tail)}"
        end
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
      {:compound, nodes} -> "<Compound, values: [#{pretty_print_statements(nodes)}]>"
      {:type, atom} -> "<Type: #{Atom.to_string(atom)}>"
      {:boolean, value} -> "<Bool: #{value}>"
      _ ->
        IO.inspect(root, label: "Got unknown token type")
        "<Unknown?>"
    end
  end

  @spec parse_compound(list(Benplusplus.Lexer.token())) :: Benplusplus.Node.node_compound()
  defp parse_compound(token_stream) do
    statements = statement_list(token_stream)

    Benplusplus.Node.construct_compound(statements)
  end

  @spec statement_list(list(Benplusplus.Lexer.token())) :: list(Benplusplus.Node.astnode())
  defp statement_list(token_stream) do
    case token_stream do
      [] -> []
      _ ->
        {node, token_stream } = statement(token_stream)
        token_stream = eat(token_stream, :colon)

        case token_stream do
          [] -> [node]
          _ ->
            [node | statement_list(token_stream)]
        end
    end
  end

  @spec statement(list(Benplusplus.Lexer.token())) :: {Benplusplus.Node.astnode(), list(Benplusplus.Lexer.token())}
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
              :typename ->
                type_atom = @typenames[token_value]

                case type_atom do
                  :nil -> error("Forgot to add typename #{token_value} to the @typenames module attribute")
                  _ ->
                    token_stream = eat(token_stream, :assignment)
                    {rhs, token_stream } = expression(token_stream, :expression)
                    { Benplusplus.Node.construct_variable_declaration(Benplusplus.Node.construct_type(type_atom), var_node, rhs), token_stream }
                end
              # Construct assignment
              _ ->
                token_stream = [{token_type, token_value} | token_stream]
                {rhs, token_stream } = expression(token_stream, :expression)
                { Benplusplus.Node.construct_assignment(var_node, rhs), token_stream }
            end
        end
      _ -> error("Expected identifier when parsing statement")
    end
  end

  @spec precedence_value(list(Benplusplus.Lexer.token())) :: {Benplusplus.Node.node_number() | Benplusplus.Node.node_var() | Benplusplus.Node.node_bool(), list(Benplusplus.Lexer.token())}
  defp precedence_value(token_stream) do
    current_token = hd(token_stream)

    case current_token do
      {:number, value} ->
        { Benplusplus.Node.construct_number(String.to_integer(value)), tl(token_stream) }
      {:true_literal, _value} ->
        { Benplusplus.Node.construct_bool(true), tl(token_stream) }
      {:false_literal, _value} ->
        { Benplusplus.Node.construct_bool(false), tl(token_stream) }
      {:identifier, value} ->
        { Benplusplus.Node.construct_variable(value), tl(token_stream) }
      # Equivalent of parenthesis
      {:left_curly, _value} ->
        # Advance past the left curly
        token_stream = eat(token_stream, :left_curly)
        # Get the inner expression
        { inner, token_stream } = expression(token_stream)
        # Advance past the right curly
        token_stream = eat(token_stream, :right_curly)
        # Return inner expression
        { inner, token_stream }
      {:minus, _value} ->
        token_stream = eat(token_stream, :minus)
        { inner, token_stream } = expression(token_stream)

        {Benplusplus.Node.construct_unary_operation(inner, :minus), token_stream}
      _ -> error("Expected lvalue in parser, got: #{elem(current_token, 0)}")
    end
  end

  @spec expression(list(Benplusplus.Lexer.token())) :: {Benplusplus.Node.astnode(), list(Benplusplus.Lexer.token())}
  def expression(token_stream) do
    expression(token_stream, :expression)
  end

  @spec expression(list(Benplusplus.Lexer.token()), :value) :: {Benplusplus.Node.astnode(), list(Benplusplus.Lexer.token())}
  defp expression(token_stream, :value) do
    precedence_value(token_stream)
  end

  @spec expression(list(Benplusplus.Lexer.token()), precedence()) :: {Benplusplus.Node.astnode(), list(Benplusplus.Lexer.token())}
  defp expression(token_stream, precedence_level) do
    { lhs, token_stream } = expression(token_stream, higher_precedence(precedence_level))

    case token_stream do
      [] -> { lhs, token_stream }
      [{op_type, op_value} | token_stream] ->
        case precedence_level do
          :equal ->
            case op_type do
              :equal ->
                {rhs, token_stream} = expression(token_stream, higher_precedence(precedence_level))
                {Benplusplus.Node.construct_binary_operation(lhs, rhs, :equal), token_stream}
                _ -> {lhs, [{op_type, op_value} | token_stream]}
            end
          :or ->
            case op_type do
              :or ->
                {rhs, token_stream} = expression(token_stream, higher_precedence(precedence_level))
                {Benplusplus.Node.construct_binary_operation(lhs, rhs, :or), token_stream}
                _ -> {lhs, [{op_type, op_value} | token_stream]}
            end
          :and ->
            case op_type do
              :and ->
                {rhs, token_stream} = expression(token_stream, higher_precedence(precedence_level))
                {Benplusplus.Node.construct_binary_operation(lhs, rhs, :and), token_stream}
                _ -> {lhs, [{op_type, op_value} | token_stream]}
            end
          :not ->
            case op_type do
              :not ->
                {rhs, token_stream} = expression(token_stream, higher_precedence(precedence_level))
                {Benplusplus.Node.construct_unary_operation(rhs, :not), token_stream}
              _ -> {lhs, [{op_type, op_value} | token_stream]}
            end
          :add_sub ->
            cond do
              op_type in [:plus, :minus] ->
                { rhs, token_stream } = expression(token_stream, higher_precedence(precedence_level))
                { Benplusplus.Node.construct_binary_operation(lhs, rhs, op_type), token_stream }
              # Add back operator
              true -> { lhs, [{op_type, op_value} | token_stream] }
            end
          :multiply_divide ->
            cond do
              op_type in [:multiply, :divide] ->
                { rhs, token_stream } = expression(token_stream, higher_precedence(precedence_level))
                { Benplusplus.Node.construct_binary_operation(lhs, rhs, op_type), token_stream }
              # Add back operator
              true -> { lhs, [{op_type, op_value} | token_stream] }
            end
          :expression ->
            { lhs, [{op_type, op_value} | token_stream] }
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
