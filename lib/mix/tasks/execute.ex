defmodule Mix.Tasks.Execute do
  use Mix.Task

  @impl Mix.Task
  def run(args) do
    IO.puts("Executing code given")
    IO.puts(Benplusplus.Execute.expression(hd args))
  end
end
