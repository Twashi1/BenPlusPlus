defmodule Benplusplus.Node do
  @type op_atoms ::
    :add | :minus | :multiply | :divide
  @type type_atoms :: :int


  @type node_number :: {:number, number()}
  @type node_binop :: {:binop, astnode(), astnode(), op_atoms()}
  @type node_var :: {:var, String.t()}
  @type node_type :: {:type, type_atoms()}
  @type node_vardecl :: {:vardecl, node_type(), node_var(), astnode()}
  @type node_assign :: {:assign, node_var(), astnode()}
  @typedoc "Integer represents the maximum stack size required for this scope"
  @type node_compound :: {:compound, list(astnode()), integer()}

  @type astnode ::
    node_number() | node_binop() | node_var() | node_type() | node_vardecl() | node_assign() | node_compound()

  @spec construct_number(number()) :: node_number()
  def construct_number(number) do
    {:number, number}
  end

  @spec construct_binary_operation(astnode(), astnode(), op_atoms()) :: node_binop()
  def construct_binary_operation(left, right, op_atom) do
    {:binop, left, right, op_atom}
  end

  @spec construct_variable(String.t()) :: node_var()
  def construct_variable(name) do
    {:var, name}
  end

  @spec construct_variable_declaration(node_type(), node_var(), astnode()) :: node_vardecl()
  def construct_variable_declaration(type, var, expression) do
    {:vardecl, type, var, expression}
  end

  @spec construct_assignment(node_var(), astnode()) :: node_assign()
  def construct_assignment(var, expression) do
    {:assign, var, expression}
  end

  @spec construct_compound(list(astnode()), integer()) :: node_compound()
  def construct_compound(statements, stack_size) do
    {:compound, statements, stack_size}
  end

  @spec construct_type(type_atoms()) :: node_type()
  def construct_type(atom) do
    {:type, atom}
  end

  @spec sizeof_type(type_atoms()) :: integer()
  def sizeof_type(atom) do
    case atom do
      :int -> 4
      _ -> :error
    end
  end
end
