defmodule Benplusplus.Codegenerator do
  def generate_code(ast_node) do
    case ast_node do
      {:number, number} -> generate_code(:number, number)
      {:binop, left, right, op_atom} -> generate_code(:binop, left, right, op_atom)
      {:program, statement_list} -> generate_code(:program, statement_list)
      _ -> ["Unknown: #{Benplusplus.Parser.prettyprint(ast_node)}"]
    end
  end

  defp generate_code(:program, statement_list) do
    case statement_list do
      :nil -> []
      _ -> [generate_code(hd(statement_list)) | generate_code(:program, tl(statement_list))]
    end
  end

  defp generate_code(:number, number) do
    ["li t0, #{number}"]
  end

  defp generate_code(:binop, left, right, op_atom) do
    left_code = generate_code(left)
    right_code = generate_code(right)

    operation_code = case op_atom do
      :plus -> "add t0, t0, t1"
      :minus -> "sub t0, t1, t0"
      :multiply -> "mul t0, t0, t1"
      :divide -> "div t0, t1, t0"
      _ -> raise("Expected mathematical operator +-*/, got #{op_atom}")
    end

    left_code ++ ["mv t1, t0"] ++ right_code ++ [operation_code]
  end
end
