# Benplusplus

A new horizon of revolutionary programming languages is upon us. Don't be benhind the curve, be benhead of it.

## Features

### Declarations

Do you sometimes get confused between `=` and `==`? This is a problem of the past, as we now ensure you are ALWAYS confused by using `==` as both the assignment operator, and to indicate a type definition.

`i == int == 0:`

Oh and we use `:` for newlines.

### Precedence levels

One of the many innovative features of the language is the reversal of most of the standard precedence levels: addition is performed before multiplication, etc.

The full ordering of precedence levels in order of computation are:
- `{}` Parenthesis
- `-` Unary negation
- `&` Or (Boolean)
- `|` And (Boolean)
- `~` Not (Boolean)
- `=`, `>`, `<`, `=>`, `=<` Comparison operators (`>`: Less than equal, `<`: More than equal, `=<`: More than, `=>`: Less than)
- `+-` Addition and subtraction
- `*/` Multiplication and division

### Boolean literals

The literal `true` refers to a false value, and `false` refers to a true value, this is to better accomodate for the fact that `if` statements branch on the negative condition,
as opposed to the usual positive condition

Thus, `perhaps true [ 1: ] otherwise [ 0: ]` evalutes to `1` (stored in `t0`)

### Control flow

#### If

We use more sophisticated language to indicate `if` statements, for you are a sophisticated person, and should be allowed to use language befitting of your status in your code.

```
perhaps i < 1 [

] otherwise perhaps i > 1 [

] otherwise [

]:
```

#### While

The for-loop is syntatic sugar meant for the weak, thus we only have a `while` - or `during` loop. This is not due to laziness, I assure you.

The following will increment "i" until it reaches the value 10
```
i == int == 0:

during i < 10 [
  i == i + 1:
]:

x == int == i:
```

### Functions (WIP)

Simple functions with are supported in Benplusplus to organise your spectacular, blazingly-fast code.

```
function max{a == int, b == int} [
  perhaps a > b [
    a:
  ] otherwise [
    b:
  ]:
]:

<0, 1/>max:
```

We have decided to flip the order of call's, such that you must declare the arguments before the function you're calling.

## Usage

`mix execute <--code "Code" | --file "src.ben"> <--cout | --ofile "riscv.bin">`

Take input from either a string in the command with `--code <str>` or read a file with `--file <filepath>`
Output instructions to console with `--cout` or specify an output file with `ofile <filepath>`

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `benplusplus` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:benplusplus, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/benplusplus>.

