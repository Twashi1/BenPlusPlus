defmodule Benplusplus.Node do
  @type op_atoms ::
    :add | :minus | :multiply | :divide | :and | :or | :equal
  @type unary_op_atoms ::
    :not | :minus
  @type type_atoms :: :int | :bool | :char | :string


  @type node_number :: {:number, number()}
  @type node_binop :: {:binop, astnode(), astnode(), op_atoms()}
  @type node_unary :: {:unary, astnode(), unary_op_atoms()}
  @type node_var :: {:var, String.t()}
  @type node_type :: {:type, type_atoms()}
  @type node_vardecl :: {:vardecl, node_type(), node_var(), astnode()}
  @type node_assign :: {:assign, node_var(), astnode()}
  @typedoc "Integer represents the maximum stack size required for this scope"
  @type node_compound :: {:compound, list(astnode())}
  @type node_bool :: {:boolean, boolean()}
  # Condition, Operation, Else
  @type node_if :: {:if, astnode(), astnode(), astnode()}
  @type node_noop :: {:noop}

  @type astnode ::
    node_number() | node_binop() | node_var() | node_type() | node_vardecl() | node_assign() | node_compound() | node_bool() | node_unary() | node_if() | node_noop()

  @spec construct_unary_operation(astnode(), unary_op_atoms()) :: node_unary()
  def construct_unary_operation(node, op_atom) do
    {:unary, node, op_atom}
  end

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

  @spec construct_noop() :: node_noop()
  def construct_noop() do
    {:noop}
  end

  @spec construct_variable_declaration(node_type(), node_var(), astnode()) :: node_vardecl()
  def construct_variable_declaration(type, var, expression) do
    {:vardecl, type, var, expression}
  end

  @spec construct_assignment(node_var(), astnode()) :: node_assign()
  def construct_assignment(var, expression) do
    {:assign, var, expression}
  end

  @spec construct_compound(list(astnode())) :: node_compound()
  def construct_compound(statements) do
    {:compound, statements}
  end

  @spec construct_type(type_atoms()) :: node_type()
  def construct_type(atom) do
    {:type, atom}
  end

  @spec construct_bool(boolean()) :: node_bool()
  def construct_bool(bool) do
    {:boolean, bool}
  end

  @spec construct_if(astnode(), astnode(), astnode()) :: node_if()
  def construct_if(condition, success_branch, failure_branch) do
    {:if, condition, success_branch, failure_branch}
  end

  @spec sizeof_type(type_atoms()) :: integer() | :error
  def sizeof_type(atom) do
    case atom do
      :bool -> 4
      :char -> 1
      :int -> 4
      :string -> 4
      _ -> :error
    end
  end
end
