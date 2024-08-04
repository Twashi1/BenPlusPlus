defmodule Benplusplus do
  def expression(str) do
    str
    |> String.graphemes()
    |> token()
    |> evaluate()
  end

  defp token(chars, acc \\ [], num \\ "") do
    case chars do
      [] ->
        [acc | [String.to_integer(num)]]

      [char | rest] ->
        cond do
          char in ["+", "-", "*", "/"] ->
            token(rest, [acc| [String.to_integer(num), char]], "")
          true ->
            token(rest, acc, num <> char)
        end
    end
  end

  defp evaluate([num | rest]) do
    evaluate(rest, num)
  end

  defp evaluate([], result) do
    result
  end

  defp evaluate([operator, num | rest], result) do
    ans = case operator do
      "+" -> result + num
      "-" -> result - num
      "/" -> div(result, num)
      "*" -> result * num
    end
    evaluate(rest, ans)
  end
end
