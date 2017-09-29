# Effects

This is a library that emulates algebraic effects in Elixir.

Now, it is not possible to do real algebraic effects on the BEAM due to lack of proper restartable continuations, so you will not be able to perform any effects that require such functionality, though thankfully such needed functionality is quite rare.  This could be worked around by performing a CPS transformation on the AST, but that would be substantially more painful and would require the entire callpath to be transformed, which makes it not work it currently (though PR's are welcome!).

## Installation

The package can be installed by adding `elixir_effects` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:elixir_effects, "~> 0.1.0"}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/effects](https://hexdocs.pm/elixir_effects).

## What?

Now what are Algebraic Effects one might ask?  If you search for information most people will quickly glaze over due to the very thick material about the subject, however it is not that complicated (to use, implementing it is a different matter).

In essence, just think that Effects are a generalization of Exceptions.  If a language has Algebraic Effects then it does not need Exceptions as the effects can emulate the exceptions.  Here is an example of a fairly simple Algebraic Effect, in this case it is a simple 'State', in that you can get and store data.

First let's encapsulate the functionality of our 'State' effect in a module:

```elixir
defmodule State do
  import Effects

  defmodule Get do
    Effects.defeffect
  end

  defmodule Set do
    Effects.defeffect [:value]
  end

  def get, do: perform %Get{}
  def set(value), do: perform %Set{value: value}

  def run(init, fun) do
    run_effect init, fun.() do
      state, %Get{} -> {:return, state}
      state, %Set{value: new_state} -> {:return, new_state, state} # Return old state
    end
  end
end
```

In this module there is defined two inner modules, these are the effects, they are defined just like structs or exceptions are.

There are also two helper methods of `get/0` and `set/1`, these just allocate an appropriate effect structure and then `perform/1` it.

Finally there is the `run/2` function, which in this case takes the initial value and a function to run wrapped in this effect manager.  Inside this function `run_effect/3` is called, passing in the initial state of the functions, the function to call (called inline, so it is passed in as `fun.()`), along with the body of cases of the effects to handle. These cases take a state argument and the effect argument and return a command of what to do to update the state or return a value or both, along with other options (see the documentation).  In this case we just return whatever the state is for `Get` and update the new state while returning the old state when `Set` is performed.

This can be used like this:

```elixir
State.run 0, fn ->
  import State
  assert 0 = get()
  assert 0 = set(42)
  assert 42 = get()
  6.28
end
```

First call the `State.run`, passing in the starting value and the function to run.  First `get()` returns the initial state, 0 here, then `set(42)` is called, which updates the state to 42 while returning the old state, then `get()` at this point now returns 42.  Finally we return `6.28` as the return value of the overall run.

Do note, in a proper effects system the continuation can be ferried off and continued later, perhaps even continued multiple times from the same point, and this ability to continue it later would allow you to make a concurrent system purely in effects as one example, however the lack of this ability on the beam will constrain such features.

## Why?

Well other than faking mutability where it otherwise does not exist, it is great for handling early returns, passing information between things without needing to pass arguments, as well as making testing far easier (keep the 'mutable' parts of your app as effects, then they become trivial to test by using a different effect manager when you run the functions).

## How?

This (ab)uses the process dictionary to be able to relatively efficiently emulate effects.  Individual effects are of course able to implement their effects however they wish, whether via another process, by accessing a database, or whatever other means they deem useful.

## Monads?

Nope, no monads here.  Pure algebraic effects are more powerful than monadic effect styles (while also being easier to read in my opinion), and they can in fact implement monadic styles as effects, however you cannot emulate algebraic effects full power with just monads thus algebraic effects are strictly more powerful.

However, to have that full power you also need to have full resumeable and (at least scoped/delimited) returnable continuations, and lacking that, like on the BEAM, does have some loss of power.  If you wish to see an efficient Algebraic Effects system I'd recommend the one being built for OCaml, you can see a great tutorial on how to use it at [https://github.com/ocamllabs/ocaml-effects-tutorial](https://github.com/ocamllabs/ocaml-effects-tutorial).
