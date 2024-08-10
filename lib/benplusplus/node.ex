defmodule Benplusplus.Node do
  @type astnode ::
    {:number, number()} |
    {:binop, astnode(), astnode(), char()} |
    {:var, String.t() } |
    # type node, identifier, then expression
    {:vardecl, astnode(), astnode(), astnode() } |
    # left var then expression
    {:assign, astnode(), astnode() } |
    {:program, list()} |
    {:type, atom()}

  def construct_node(:number, number) do
    {:number, number}
  end

  def construct_node(:binop, left, right, op_atom) do
    {:binop, left, right, op_atom}
  end

  def construct_node(:var, name) do
    {:var, name}
  end

  def construct_node(:vardecl, type, var, expression) do
    {:vardecl, type, var, expression}
  end

  def construct_node(:assign, var, expression) do
    {:assign, var, expression}
  end

  def construct_node(:program, statements) do
    {:program, statements}
  end

  def construct_node(:type, atom) do
    {:type, atom}
  end
end
