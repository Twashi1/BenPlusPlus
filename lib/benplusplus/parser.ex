defmodule Benplusplus.Parser do
  _ = """
  Current definition:

  <program> ::= <statement_list>
  <compound> ::= [ <statement_list> ]
  <statement_list> ::= <statement> | <statement> <statement_list>
  <statement> ::= <declaration> : | <assignment> : | <compound> : | <if> :
  <declaration> ::= <identifier> == <type> == <expression>
  <assignment> ::= <identifier> == <expression>
  <type> ::= int | bool
  <expression> ::= <number> | <identifier> | <expression> <operation> <expression> | {<expression>}
  <operation> ::= + | - | / | * | = | & | \| |
  <if> ::= perhaps <expression> <compound> | perhaps <expression> otherwise <compound> | perhaps <expression> otherwise <if>
  """
  @typenames %{"int" => :int, "string" => :string, "bool" => :bool, "char" => :char}

  @type precedence() :: :value | :comparison | :and | :or | :not | :add_sub | :multiply_divide | :expression

  @spec error(String.t()) :: no_return()
  defp error(message) do
    raise RuntimeError, message: "Parser error: #{message}"
  end

  @spec higher_precedence(precedence()) :: precedence()
  defp higher_precedence(precedence_level) do
    case precedence_level do
      :or -> :value
      :and -> :or
      :not -> :and
      :comparison -> :not
      :add_sub -> :comparison
      :multiply_divide -> :add_sub
      :expression -> :multiply_divide
    end
  end

  @spec parse(list(Benplusplus.Lexer.token())) :: Benplusplus.Node.node_compound()
  def parse(token_stream) do
    {root, _} = parse_program(token_stream)

    root
  end

  @spec pretty_print_list(list(Benplusplus.Node.astnode())) :: String.t()
  def pretty_print_list(statements) do
    case statements do
      [] -> ""
      [head | tail] ->
        case tail do
          [] -> "#{pretty_print_node(head)}"
          _ -> "#{pretty_print_node(head)}, #{pretty_print_list(tail)}"
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
      {:compound, nodes} -> "<Compound, values: [#{pretty_print_list(nodes)}]>"
      {:type, atom} -> "<Type: #{Atom.to_string(atom)}>"
      {:boolean, value} -> "<Bool: #{value}>"
      {:parameter, var, type} -> "<Param: #{pretty_print_node(var)} == #{pretty_print_node(type)}>"
      {:argument, expr} -> "<Arg: #{pretty_print_node(expr)}>"
      {:if, condition, success_branch, failure_branch} -> "<If(#{pretty_print_node(condition)}), Success: #{pretty_print_node(success_branch)}, Failure: #{pretty_print_node(failure_branch)}>"
      {:funcdecl, name, parameters, return_type, compound} -> "<FuncDecl: #{name}(#{pretty_print_list(parameters)}) -> (#{pretty_print_node(return_type)}): #{pretty_print_node(compound)}>"
      {:funccall, name, arguments} -> "<FuncCall: #{name}(#{pretty_print_list(arguments)})>"
      _ ->
        IO.inspect(root, label: "Got unknown token type")
        "<Unknown?>"
    end
  end

  @spec parse_program(list(Benplusplus.Lexer.token())) :: { Benplusplus.Node.node_compound(), list(Benplusplus.Lexer.token()) }
  defp parse_program(token_stream) do
    {statements, token_stream } = statement_list(token_stream)

    { Benplusplus.Node.construct_compound(statements), token_stream }
  end

  @spec parse_compound(list(Benplusplus.Lexer.token())) :: { Benplusplus.Node.node_compound(), list(Benplusplus.Lexer.token()) }
  defp parse_compound(token_stream) do
    token_stream = eat(token_stream, :left_square)
    { statements, token_stream } = statement_list(token_stream)
    token_stream = eat(token_stream, :right_square)

    { Benplusplus.Node.construct_compound(statements), token_stream}
  end

  @spec parse_if(list(Benplusplus.Lexer.token())) :: {Benplusplus.Node.node_if(), list(Benplusplus.Lexer.token())}
  defp parse_if(token_stream) do
    token_stream = eat(token_stream, :if)
    {condition, token_stream} = expression(token_stream)
    IO.puts("Got condition: #{pretty_print_node(condition)}, with remaining stream: #{Benplusplus.Lexer.pretty_print_tokens(token_stream)}")
    {success_branch, token_stream} = parse_compound(token_stream)

    case token_stream do
      [] -> {Benplusplus.Node.construct_if(condition, success_branch, Benplusplus.Node.construct_noop()), token_stream}
      [{token_type, _token_value} | tail] ->
        case token_type do
          :else ->
            { failure_branch, token_stream } = statement(tail)
            {Benplusplus.Node.construct_if(condition, success_branch, failure_branch), token_stream}
          _ -> {Benplusplus.Node.construct_if(condition, success_branch, Benplusplus.Node.construct_noop()), token_stream}
        end
    end
  end

  @spec statement_list(list(Benplusplus.Lexer.token())) :: {list(Benplusplus.Node.astnode()), list(Benplusplus.Lexer.token())}
  defp statement_list(token_stream) do
    case token_stream do
      [] -> {[], []}
      [{token_type, _token_value} | _tail_token_stream] ->
        case token_type do
          :right_square -> {[], token_stream}
          _ ->
            {node, token_stream } = statement(token_stream)
            token_stream = eat(token_stream, :colon)

            case token_stream do
              [] -> {[node], token_stream}
              _ ->
                {tail, token_stream} = statement_list(token_stream)
                {[node | tail], token_stream}
            end
        end
    end
  end

  @spec parse_parameter_list(list(Benplusplus.Lexer.token())) :: {list(Benplusplus.Node.node_parameter()), list(Benplusplus.Lexer.token())}
  defp parse_parameter_list(token_stream) do
    {parameter, token_stream} = case token_stream do
      [] -> error("Expected closing bracket or parameter in parameter list")
      [{:right_curly, _value} | _tail] ->
        {:nil, token_stream}
      _ ->
        {{:identifier, var_name}, token_stream} = match(token_stream, :identifier)
        token_stream = eat(token_stream, :assignment)
        {{:typename, type_name}, token_stream} = match(token_stream, :typename)

        type_atom = case @typenames[type_name] do
          :nil -> error("Couldn't convert typename #{type_name}")
          type_atom -> type_atom
        end

        {Benplusplus.Node.construct_parameter(Benplusplus.Node.construct_variable(var_name), Benplusplus.Node.construct_type(type_atom)), token_stream}
    end

    case parameter do
      :nil -> {[], token_stream}
      _ ->
        case token_stream do
          [] -> error("Expected closing bracket or comma in parameter list")
          [token | _tail] ->
            case token do
              {:comma, _value} ->
                token_stream = eat(token_stream, :comma)
                {parameters, token_stream} = parse_parameter_list(token_stream)
                {[parameter | parameters], token_stream}
              _ -> {[parameter], token_stream}
            end
        end
    end
  end

  # TODO: use this function in more places
  @spec parse_type(list(Benplusplus.Lexer.token())) :: {Benplusplus.Node.node_type(), list(Benplusplus.Lexer.token())}
  defp parse_type(token_stream) do
    {{:typename, token_value}, token_stream} = match(token_stream, :typename)

    type_atom = @typenames[token_value]

    case type_atom do
      :nil -> error("Forgot to add typename #{token_value} to the @typenames module attribute")
      _ -> { Benplusplus.Node.construct_type(type_atom), token_stream }
    end
  end

  @spec parse_function(list(Benplusplus.Lexer.token())) :: {Benplusplus.Node.node_function_declaration(), list(Benplusplus.Lexer.token())}
  defp parse_function(token_stream) do
    token_stream = eat(token_stream, :function)

    {{:identifier, name}, token_stream} = match(token_stream, :identifier)

    token_stream = eat(token_stream, :left_curly)

    {parameters, token_stream} = parse_parameter_list(token_stream)

    token_stream = eat(token_stream, :right_curly)

    token_stream = eat(token_stream, :assignment)

    {return_type, token_stream} = parse_type(token_stream)

    {code, token_stream} = parse_compound(token_stream)

    {Benplusplus.Node.construct_function_declaration(name, parameters, return_type, code), token_stream}
  end

  @spec parse_argument_list(list(Benplusplus.Lexer.token())) :: {list(Benplusplus.Node.astnode()), list(Benplusplus.Lexer.token())}
  defp parse_argument_list(token_stream) do
    # TODO: simplify
    {argument, token_stream} = case token_stream do
      [] -> error("Expected closing bracket or argument in argument list")
      [{:closing_angle_bracket, _value} | _tail] ->
        {:nil, token_stream}
      _ ->
        expression(token_stream)
    end

    case argument do
      :nil -> {[], token_stream}
      _ ->
        case token_stream do
          [] -> error("Expected closing bracket or comma in argument list")
          [token | _tail] ->
            case token do
              {:comma, _value} ->
                token_stream = eat(token_stream, :comma)
                {arguments, token_stream} = parse_argument_list(token_stream)
                {[argument | arguments], token_stream}
              _ -> {[argument], token_stream}
            end
        end
    end
  end

  @spec parse_function_call(list(Benplusplus.Lexer.token())) :: {Benplusplus.Node.node_function_call(), list(Benplusplus.Lexer.token())}
  defp parse_function_call(token_stream) do
    token_stream = eat(token_stream, :more_eq)

    {arguments, token_stream} = parse_argument_list(token_stream)

    token_stream = eat(token_stream, :closing_angle_bracket)

    {{:identifier, function_name}, token_stream} = match(token_stream, :identifier)

    {Benplusplus.Node.construct_function_call(function_name, arguments), token_stream}
  end

  @spec statement(list(Benplusplus.Lexer.token())) :: {Benplusplus.Node.astnode(), list(Benplusplus.Lexer.token())}
  defp statement(token_stream) do
    [current_token | token_stream] = token_stream

    case current_token do
      {:if, _value} ->
        parse_if([current_token | token_stream])
      {:function, _value} ->
        parse_function([current_token | token_stream])
      {:more_eq, _value} ->
        parse_function_call([current_token | token_stream])
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
      {:left_square, _value} ->
        parse_compound([current_token | token_stream])
      _ -> expression([current_token | token_stream])
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
      {:more_eq, _value} ->
        parse_function_call(token_stream)
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
          :comparison ->
            cond do
              op_type in [:equal, :less_than, :more_than, :less_eq, :more_eq] ->
                {rhs, token_stream} = expression(token_stream, higher_precedence(precedence_level))
                {Benplusplus.Node.construct_binary_operation(lhs, rhs, op_type), token_stream}
              true -> {lhs, [{op_type, op_value} | token_stream]}
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
      [current_token | tail] -> if elem(current_token, 0) == token_type, do: tail, else: error("[Eat] Expected token <#{token_type}> got token #{elem(current_token, 0)} from stream #{Benplusplus.Lexer.pretty_print_tokens(token_stream)}")
    end
  end

  @spec eat(list(Benplusplus.Lexer.token()), atom()) :: {Benplusplus.Lexer.token(), list(Benplusplus.Lexer.token())}
  defp match(token_stream, token_type) do
    case token_stream do
      [] -> error("Expected token #{token_type} but got end of file")
      [current_token | tail] -> if elem(current_token, 0) == token_type, do: {current_token, tail}, else: error("[Match] Expected token <#{token_type}> got token #{elem(current_token, 0)} from stream #{Benplusplus.Lexer.pretty_print_tokens(token_stream)}")
    end
  end
end
