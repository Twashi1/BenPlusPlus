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

    context = %Benplusplus.Codegenerator.Context{}

    instructions = Benplusplus.Codegenerator.generate_code(ast_root, context)

    IO.inspect(instructions, label: "Instructions: ")
  end
end
