defmodule Benplusplus.Parser do
  def parse(token_stream) do
    # Expect declaration
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
