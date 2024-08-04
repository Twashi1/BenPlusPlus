defmodule Mix.Tasks.Execute do
  use Mix.Task

  @impl Mix.Task
  def run(args) do
    IO.puts("Executing code given")
    input = hd(args)
    IO.puts(input)
    tokens = Benplusplus.Lexer.tokenise(input)
    IO.puts(Benplusplus.Lexer.pretty_print(tokens))
  end
end
