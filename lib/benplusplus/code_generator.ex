defmodule Benplusplus.Codegenerator do
  # TODO: Returns string
  def generate(ast_node) do
    elem(visit(ast_node), 0)
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
