defmodule ElixirEffects do
  @moduledoc """
  Documentation for ElixirEffects.
  """

  @doc """
  Define a new effect

  ## Examples

      iex> defmodule TestEffect do
      ...>   ElixirEffects.defeffect [:a_field]
      ...> end
      iex> TestEffect.effect()
      %{__struct__: ElixirEffectsTest.TestEffect, __exception__: true, __effect__: true, a_field: nil}

  """
  defmacro defeffect(fields \\ []) do
    fields = List.wrap(fields)
    quote do
      eff_type = defexception([__effect__: true] ++ unquote(fields))

      def effect(), do: __struct__()
      def effect(args), do: __struct__(args)

      def message(%{message: message}), do: message
      def message(eff), do: "<Effect: #{inspect eff}>"
      defoverridable message: 1
    end
  end



  @doc """
  Run an effect

  Return values of effect clauses must be one of:

  * `{:return, value}` -> Returns `value` from the `perform` call.
  * `{:return, new_state, value}` -> Updates the state to `new_state` and returns `value` from the `perform` call.
  * `:done` -> Returns nil from `run_effect`.
  * `{:done, return_value}` -> Returns the `return_value` from `run_effect`.
  * `{:throw, to_throw}` -> Throws `to_throw` from the `perform` call.
  * `{:raise, to_raise}` -> Raises `to_raise` from the `perform` call.

  Optional initial state value can be passed in first, defaults to nil.

  Optional third argument of options supports these values:

  * `key: value` -> To distinguish recursive calls to a single effect, you can key each to access each (not implemented yet).
  """
  defmacro run_effect(init \\ nil, expr, opts \\ [], [do: body]) do
    state_key = Macro.escape({opts[:key] || :state, __CALLER__.module, __CALLER__.function})

    clauses =
      case body do
        nil -> []
        [{:->, _, _} | _] -> body
      end

    effects =
      clauses
      |> Enum.map(fn
        {:->, _, [[eff], eff_body]} ->
          eff_type = get_effect_type_from_ast(eff)
          {eff_type, {[Macro.var(:state, nil), eff], eff_body}}
        {:->, _, [[state_var, eff], eff_body]} ->
          eff_type = get_effect_type_from_ast(eff)
          {eff_type, {[state_var, eff], eff_body}}
      end)
      |> Enum.map(fn {eff_type, eff} ->
          eff_type = __CALLER__.aliases[eff_type] || eff_type
          {eff_type, eff}
        end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    register_effects =
      effects
      |> Enum.map(fn {eff_type, clauses} ->
        clauses =
          clauses
          |> Enum.map(fn {[state_var, eff], eff_body} ->
            quote generated: true do
              (unquote(eff)) ->
                [unquote(state_var) | rest_states] = Process.get(unquote(state_key))
                _ = unquote(state_var)
                case unquote(eff_body) do
                  :done -> throw {:EffectsDone, unquote(state_key), nil}
                  {:done, return_value} -> throw {:EffectsDone, unquote(state_key), return_value}
                  {:throw, to_throw} -> throw to_throw
                  {:raise, to_raise} -> raise to_raise
                  {:return, return_value} -> return_value
                  {:return, new_state, return_value} ->
                    Process.put(unquote(state_key), [new_state | rest_states])
                    return_value
                  unhandled -> throw {:unhandled_effect_perform_return, unhandled}
                end
            end |> hd()
          end)
        fnast = {:fn, [], clauses}
        quote do
          Process.put(unquote(eff_type), [unquote(fnast) | Process.get(unquote(eff_type))])
        end
      end)

    unregister_effects =
      effects
      |> Enum.map(fn {eff_type, _clauses} ->
        quote do
          case Process.get(unquote(eff_type)) do
            [_ | nil] -> Process.delete(unquote(eff_type))
            [_ | previous] -> Process.put(unquote(eff_type), previous)
          end
        end
      end)

    quote do
      try do
        # Setup effect
        unquote_splicing(register_effects)
        Process.put(unquote(state_key), [unquote(init) | Process.get(unquote(state_key))])

        # Run effect
        unquote(expr)
      catch
        {:EffectsDone, unquote(state_key), returned} -> returned
      after
        # Teardown effect
        unquote_splicing(unregister_effects)
        case Process.get(unquote(state_key)) do
          [_ | nil] -> Process.delete(unquote(state_key))
          [_ | previous] -> Process.put(unquote(state_key), previous)
        end
      end
    end
    #|> Macro.to_string |> IO.puts |> throw
  end


  @doc """
  Pass in an effect to perform by the wrapping effect manager(s)
  """
  defmacro perform(effect) do
    quote do
      effect = unquote(effect)
      case Process.get(effect.__struct__) do
        [fun | _] when is_function(fun, 1) -> fun.(effect)
        _ -> throw {:effect_is_not_currently_being_handled, effect.__struct__, Process.get_keys()}
      end
    end
  end


  ## Helpers

  defp get_effect_type_from_ast(ast)
  defp get_effect_type_from_ast({:%, _, [{:__aliases__, _, names}, _]}), do: Module.concat(names)
  defp get_effect_type_from_ast(ast), do: throw {:unhandled_ast_type, ast}

end
