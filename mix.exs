defmodule Para.MixProject do
  use Mix.Project

  def project do
    [
      app: :para,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      description: "A toolkit for data mapping and language integrated query for Elixir",
      package: package(),

      # Docs
      name: "Ecto",
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [{:ecto, "~> 3.7"}]
  end

  def package do
    [
      files: ~w(lib mix.exs README* LICENSE),
      maintainers: ["Syamil MJ"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/syamilmj/para"}
    ]
  end

  defp docs do
    [
      extras: "README.md"
    ]
  end
end
