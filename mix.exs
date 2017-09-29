defmodule ElixirEffects.Mixfile do
  use Mix.Project

  def project do
    [
      app: :elixir_effects,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
    ]
  end

  def application do
    [
      extra_applications: [
        # :logger,
      ]
    ]
  end

  defp deps do
    [
      {:cortex, "~> 0.4.2", only: [:dev, :test]},
      {:credo, "~> 0.8.6", only: [:dev, :test]},
    ]
  end
end
