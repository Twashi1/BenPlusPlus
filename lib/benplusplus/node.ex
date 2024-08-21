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
  # Condition, Success branch, Failure branch
  @type node_if :: {:if, astnode(), astnode(), astnode()}
  # Condition, Body
  @type node_while :: {:while, astnode(), astnode()}

  @type node_parameter :: {:parameter, node_var(), node_type()}
  @type node_function_declaration :: {:funcdecl, String.t(), list(node_parameter()), node_type(), node_compound()}
  @type node_function_call :: {:funccall, String.t(), list(astnode())}

  @type node_noop :: {:noop}

  @type astnode ::
    node_number() | node_binop() | node_var() | node_type() | node_vardecl() | node_assign() | node_compound() | node_bool() | node_unary() | node_if() | node_noop() |
    node_parameter() | node_function_declaration() | node_function_call() | node_while()

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

  @spec construct_parameter(node_var(), node_type()) :: node_parameter()
  def construct_parameter(var, type) do
    {:parameter, var, type}
  end

  @spec construct_function_declaration(String.t(), list(node_parameter()), node_type(), node_compound()) :: node_function_declaration()
  def construct_function_declaration(name, parameters, return_type, compound) do
    {:funcdecl, name, parameters, return_type, compound}
  end

  @spec construct_function_call(String.t(), list(astnode())) :: node_function_call()
  def construct_function_call(name, arguments) do
    {:funccall, name, arguments}
  end

  @spec construct_while(astnode(), astnode()) :: node_while()
  def construct_while(condition, compound) do
    {:while, condition, compound}
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
