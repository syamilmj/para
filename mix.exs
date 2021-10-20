defmodule Para.MixProject do
  use Mix.Project

  @version "0.2.2"
  @source_url "https://github.com/syamilmj/para"

  def project do
    [
      app: :para,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      description: "A declarative way to parse and validate parameters",
      package: package(),

      # Docs
      name: "Para",
      docs: [source_ref: "v#{@version}", main: "Para", extras: ["CHANGELOG.md"]]
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
    [
      {:ecto, "~> 3.7"},
      {:ex_doc, "~> 0.20", only: :dev, runtime: false}
    ]
  end

  def package do
    [
      files: ~w(lib mix.exs README* LICENSE CHANGELOG.md .formatter.exs),
      maintainers: ["Syamil MJ"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
