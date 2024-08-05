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
    # Expect expression
  end

  defp precedence_value(token_stream) do
    current_token = hd(token_stream)

    case current_token do
      {:number, value} ->
        IO.inspect(tl(token_stream), label: "Constructing value node")
        { Benplusplus.Node.construct_node(:number, String.to_integer(value)), tl(token_stream) }
      _ -> raise("Expected number in parser, got: #{elem(current_token, 0)}")
    end
  end

  defp visit(head) do
    case head do
      {:number, number} -> Benplusplus.Node.construct_node(:number, number)
      {:binop, lhs, rhs, op} ->
        IO.inspect(lhs, label: "Left node")
        IO.inspect(rhs, label: "Right node")

        { :number, lhs_value } = visit(lhs)
        { :number, rhs_value } = visit(rhs)

        IO.inspect(lhs_value, label: "Visit left returned")
        IO.inspect(rhs_value, label: "Visit right returned")

        case op do
          :plus ->      Benplusplus.Node.construct_node(:number, lhs_value + rhs_value)
          :minus ->     Benplusplus.Node.construct_node(:number, lhs_value - rhs_value)
          :multiply ->  Benplusplus.Node.construct_node(:number, lhs_value * rhs_value)
          :divide ->    Benplusplus.Node.construct_node(:number, div(lhs_value, rhs_value))
          _ -> raise("Expected mathematical operator +-*/, got #{op}")
        end
      _ -> raise("Unexpected visit type")
    end
  end

  def tmp_evalute(token_stream) do
    { ast_head, _ } = expression(token_stream, :expression)

    evaluted = visit(ast_head)

    case evaluted do
      {:number, number} -> number
      _ -> raise("Evalute returned #{evaluted} instead of number")
    end
  end

  defp expression(token_stream, :value) do
    precedence_value(token_stream)
  end

  defp expression(token_stream, precedence_level) do
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

  defp declaration(token_stream) do

  end
end
