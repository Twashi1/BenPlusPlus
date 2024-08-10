defmodule Benplusplus.Codegenerator do
  # TODO: Returns string
  def generate(ast_node) do
    elem(visit(ast_node), 0)
  end

  def generate_code(ast_node) do
    code = generate_code(ast)
  end

  defp generate_code({:number, number}) do
    ["li t0, #(number)"]
  end

  defp generate_code({:binop, left, right, op_atom}) do
    left_code = generate_code(left)
    right_code = generate_code(right)

    operation_code = case op_atom do
      '+' -> "add t0, t0, t1"
      '-' -> "sub t0, t1, t0"
      '*' -> "mul t0, t0, t1"
      '/' -> "div t0, t1, t0"
      _ -> raise("Expected mathematical operator +-*/, got #{op}")
    end

    left_code ++ ["mv t1, t0"] ++ right_code ++ [operation_code]
  end

  defp visit(head) do
    case head do
      {:number, number} -> Benplusplus.Node.construct_node(:number, number)
      {:binop, lhs, rhs, op} ->
        { :number, lhs_value } = visit(lhs)
        { :number, rhs_value } = visit(rhs)

        case op do
          :plus ->      Benplusplus.Node.construct_node(:number, lhs_value + rhs_value)
          :minus ->     Benplusplus.Node.construct_node(:number, lhs_value - rhs_value)
          :multiply ->  Benplusplus.Node.construct_node(:number, lhs_value * rhs_value)
          :divide ->    Benplusplus.Node.construct_node(:number, div(lhs_value, rhs_value))
          _ -> raise("Expected mathematical operator +-*/, got #{op}")
        end
      _ -> raise("Unexpected visit type")
    end
  end
end
