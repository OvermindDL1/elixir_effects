defmodule ElixirEffectsTest do
  use ExUnit.Case
  doctest ElixirEffects

  defmodule TestEffectVoid do
    ElixirEffects.defeffect
  end

  defmodule TestEffectVoidN do
    ElixirEffects.defeffect []
  end

  defmodule TestEffectField1 do
    ElixirEffects.defeffect [:a_field]
  end

  test "Effect struct constructors" do
    assert %TestEffectVoid{__effect__: true} == TestEffectVoid.effect()
    assert %TestEffectVoidN{__effect__: true} == TestEffectVoidN.effect()
    assert %TestEffectField1{__effect__: true, a_field: nil} == TestEffectField1.effect()
    assert %TestEffectField1{__effect__: true, a_field: 42} == TestEffectField1.effect(a_field: 42)
  end

  test "Effect messages" do
    assert "<Effect: %ElixirEffectsTest.TestEffectVoid{__effect__: true}>" =
      TestEffectVoid.message(TestEffectVoid.effect())
    assert "<Effect: %ElixirEffectsTest.TestEffectVoidN{__effect__: true}>" =
      TestEffectVoidN.message(TestEffectVoidN.effect())
    assert "<Effect: %ElixirEffectsTest.TestEffectField1{__effect__: true, a_field: nil}>" =
      TestEffectField1.message(TestEffectField1.effect())
    assert "<Effect: %ElixirEffectsTest.TestEffectField1{__effect__: true, a_field: 42}>" =
      TestEffectField1.message(TestEffectField1.effect(a_field: 42))
  end

  test "run_effect and perform" do
    ElixirEffects.run_effect (
      assert 1 == ElixirEffects.perform(%TestEffectVoid{})
      assert 2 == ElixirEffects.perform(%TestEffectVoidN{})
      assert_raise(ArgumentError, "should not be 42", fn -> ElixirEffects.perform(%TestEffectField1{a_field: 42}) end)
      :never_returns = ElixirEffects.perform(%TestEffectField1{})
      assert :never_called = ElixirEffects.perform(%TestEffectVoid{})
    ) do
      %TestEffectVoid{} -> {:return, 1}
      state, %TestEffectVoidN{} -> {:return, state, 2}
      %TestEffectField1{a_field: 42} -> {:raise, %ArgumentError{message: "should not be 42"}}
      %TestEffectField1{} -> :done
    end
  end


  # Test a 'State' effect
  defmodule State do
    import ElixirEffects

    defmodule Get do
      ElixirEffects.defeffect
    end

    defmodule Set do
      ElixirEffects.defeffect :value
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

  test "State Effect" do
    assert 6.28 =
      State.run 0, fn ->
        import State
        assert 0 = get()
        assert 0 = set(42)
        assert 42 = get()
        6.28
      end
  end
end
