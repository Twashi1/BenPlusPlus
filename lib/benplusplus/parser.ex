defmodule Benplusplus.Parser do
  import Benplusplus.Lexer

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

  defp expression(token_stream, precedence_level) do
    case precedence_level do
      # Base case recursion
      :value ->
        expect(token_stream, :number)
      :add_sub ->
        [lhs | token_stream] = expression(token_stream, higher_precedence(precedence_level))
        # Check op character
        [op | _] = token_stream

        if elem(op, 0) in [:plus, :minus] do

        end
    end
  end

  defp error(message) do
    IO.puts("Parser error: #{message}")
    :error
  end

  defp expect(token_stream, token_type) do
    case token_stream do
      [] -> error("Expected token #{token_type} but got end of file")
      [currentToken | tail] -> if elem(currentToken, 0) == token_type, do: [currentToken | tail], else: error("Expected token #{token_type} got token #{elem(currentToken, 0)}")
    end
  end

  defp declaration(token_stream) do

  end
end
