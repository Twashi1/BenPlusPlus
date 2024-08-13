defmodule Benplusplus.Node do
  @type astnode ::
    {:number, number()} |
    # LHS, RHS, operation (token type)
    {:binop, astnode(), astnode(), atom()} |
    {:var, String.t() } |
    # Type, variable, then expression
    {:vardecl, astnode(), astnode(), astnode() } |
    # Variable then expression
    {:assign, astnode(), astnode() } |
    # List of statements, and integer indicating stack size
    {:compound, list(), integer()} |
    {:type, atom()}

  def construct_number(number) do
    {:number, number}
  end

  def construct_binary_operation(left, right, op_atom) do
    {:binop, left, right, op_atom}
  end

  def construct_variable(name) do
    {:var, name}
  end

  def construct_variable_declaration(type, var, expression) do
    {:vardecl, type, var, expression}
  end

  def construct_assignment(var, expression) do
    {:assign, var, expression}
  end

  def construct_compound(statements, stack_size) do
    {:compound, statements, stack_size}
  end

  def construct_type(atom) do
    {:type, atom}
  end

  def sizeof_type(atom) do
    case atom do
      :int -> 4
      # TODO: error
      _ -> 0
    end
  end
end
