defmodule Mix.Tasks.Execute do
  use Mix.Task

  @impl Mix.Task
  def run(args) do
    IO.puts(Benplusplus.expression(hd args))
  end
end
