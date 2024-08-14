defmodule Mix.Tasks.Execute do
  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {parsed, _, _} = OptionParser.parse(args, switches: [file: :string, code: :string])
    IO.inspect(parsed, label: "Received args")

    code = parsed[:code]

    tokens = case code do
      nil ->
        filepath = parsed[:file]
        IO.puts("Reading file #{filepath}")

        # Load filepath and set to code
        {status, filedata} = File.read(filepath)

        case status do
          :ok -> Benplusplus.Lexer.tokenise(filedata)
          :error -> raise("Couldn't load file, couldn't load code")
        end
      _ -> Benplusplus.Lexer.tokenise(code)
    end

    IO.puts(Benplusplus.Lexer.pretty_print_tokens(tokens))

    ast_root = Benplusplus.Parser.parse(tokens)

    IO.puts("AST: #{Benplusplus.Parser.pretty_print_node(ast_root)}")

    instructions = Benplusplus.Codegenerator.generate_instructions(ast_root)
    output_string = instructions |> Enum.join("\n")

    IO.puts("Finished compilation")

    # Look for output
    case parsed[:cout] do
      nil ->
        case parsed[:ofile] do
          nil -> IO.puts("Must specify output as either --cout or --ofile 'file.txt'")
          filepath ->
            IO.puts("Writing to file #{filepath}")
            File.write(filepath, output_string)
        end
      _ -> IO.puts(output_string)
    end
  end
end
