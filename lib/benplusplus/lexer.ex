defmodule Benplusplus.Lexer do
  @tokens [
    {"perhaps", :if},
    {"otherwise perhaps", :elif},
    {"otherwise", :else},
    {"int", :int},
    {"string", :string},
    {"char", :char},
    {"[a-zA-Z_][a-zA-Z0-9_]*", :identifier},
    {"[0-9]+", :number},
    {"\\*", :multiply},
    {"\\/", :divide},
    {"-", :minus},
    {"\\+", :plus},
    {"==", :assignment},
    {"=", :equals},
    {":", :colon},
    {"\\(", :left_paren},
    {"\\)", :right_paren},
    {"\\[", :left_square},
    {"\\]", :right_square},
    {"\\{", :left_curly},
    {"\\}", :right_curly},
    {"[ \t\r\n]+", :whitespace}
  ]

  def tokenise(input) do
    tokenise(input, [])
  end

  defp tokenise("", tokens) do
    Enum.reverse(tokens)
  end

  defp tokenise(input, tokens) do
    {matched, type} = Enum.find(@tokens, fn {regex, _type} ->
      Regex.match?(~r/^#{regex}/, input)
    end)

    [match] = Regex.run(~r/^#{matched}/, input)
    rest = String.slice(input, String.length(match), String.length(input)-String.length(match))

    case type do
      :whitespace -> tokenise(rest, tokens)
      _ -> tokenise(rest, [{type, match} | tokens])
    end
  end

  def pretty_print(tokens) do
    tokens
    |> Enum.map(fn {type, value} -> "#{type}: #{value}" end)
    |> Enum.join("\n")
  end

end
