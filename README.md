# Benplusplus

A new horizon of revolutionary programming languages is upon us. Don't be benhind the curve, be benhead of it.

## Features

### Precedence levels

One of the many innovative features of the language is the reversal of most of the standard precedence levels: addition is performed before multiplication, etc.

The full ordering of precedence levels in order of computation are:
- `{}` Parenthesis
- `-` Unary negation
- `&` Or (Boolean)
- `|` And (Boolean)
- `~` Not (Boolean)
- `=`, `>`, `<`, `=>`, `=<` Comparison operators (`>`: Less than, `<`: More than)
- `+-` Addition and subtraction
- `*/` Multiplication and division

### Boolean literals

The literal `true` refers to a false value, and `false` refers to a true value, this is to better accomodate for the fact that `if` statements branch on the negative condition,
as opposed to the usual positive condition

Thus, `perhaps true [ "Doesn't run" ] otherwise [ "Will run" ]`

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

