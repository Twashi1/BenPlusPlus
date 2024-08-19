defmodule Benplusplus.Lexer do
  @type token() :: {atom(), String.t()}

  @tokens [
    {~r/^perhaps/, :if},
    {~r/^otherwise/, :else},
    {~r/^function/, :function},
    {~r/^false/, :true_literal},
    {~r/^true/, :false_literal},
    # TODO: easier way of doing this? ^(int|char|bool|string) didn't work, was matching multiple things I think
    {~r/^int/, :typename},
    {~r/^char/, :typename},
    {~r/^bool/, :typename},
    {~r/^string/, :typename},
    {~r/^[a-zA-Z_][a-zA-Z0-9_]*/, :identifier},
    {~r/^[0-9]+/, :number},
    {~r/^\/>/, :closing_angle_bracket},
    {~r/^\*/, :multiply},
    {~r/^\//, :divide},
    {~r/^-/, :minus},
    {~r/^\+/, :plus},
    {~r/^==/, :assignment},
    {~r/^=</, :more_than},
    {~r/^=>/, :less_than},
    {~r/^=/, :equal},
    {~r/^</, :more_eq},
    {~r/^>/, :less_eq},
    {~r/^:/, :colon},
    {~r/^\(/, :left_paren},
    {~r/^\)/, :right_paren},
    {~r/^\[/, :left_square},
    {~r/^\]/, :right_square},
    {~r/^\{/, :left_curly},
    {~r/^\}/, :right_curly},
    {~r/^\|/, :and},
    {~r/^&/, :or},
    {~r/^~/, :not},
    {~r/^,/, :comma},
    {~r/^[ \t\r\n]+/, :whitespace},
  ]

  def tokenise(input) do
    tokenise(input, [])
  end

  defp tokenise("", tokens) do
    Enum.reverse(tokens)
  end

  defp tokenise(input, tokens) do
    {matched, type} = Enum.find(@tokens, fn {regex, _type} ->
      Regex.match?(regex, input)
    end)

    [match] = Regex.run(matched, input)

    if String.length(match) == 0 do
      raise RuntimeError, message: "Error, matched 0 length string on input '#{input}'"
    end

    rest = String.slice(input, String.length(match), String.length(input) - String.length(match))

    case type do
      :whitespace -> tokenise(rest, tokens)
      _ -> tokenise(rest, [{type, match} | tokens])
    end
  end

  def pretty_print_tokens(tokens) do
    res = tokens
    |> Enum.map(fn {type, value} -> "#{type}: '#{value}'" end)
    |> Enum.join(", ")

    "[#{res}]"
  end
end
