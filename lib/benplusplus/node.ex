defmodule Benplusplus.Node do
  @type astnode ::
    {:number, number()} |
    {:binop, astnode(), astnode(), char()}

  def construct_node(:number, number) do
    {:number, number}
  end

  def construct_node(:binop, left, right, op_atom) do
    {:binop, left, right, op_atom}
  end
end
