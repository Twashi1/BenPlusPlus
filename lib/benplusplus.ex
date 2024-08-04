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
        [String.to_integer(num) | acc]

      [char | rest] ->
        cond do
          char in ["+", "-", "*", "/"] ->
            token(rest, [char, String.to_integer(num) | acc], "")
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
      "/" -> div(num, result)
      "*" -> result * num
    end
    evaluate(rest, ans)
  end
end
