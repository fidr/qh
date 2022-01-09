defmodule Qh.MixProject do
  use Mix.Project

  def project do
    [
      app: :qh,
      version: "0.1.0",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      package: package(),
      description: description(),
      docs: docs(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ecto, "~> 3.0"},
      {:ecto_sql, "~> 3.7", only: :test},
      {:postgrex, ">= 0.0.0", only: :test},
      {:ex_doc, "~> 0.26", only: :dev, runtime: false}
    ]
  end

  def description do
    """
    Ecto query helper for iex (Rails style)
    """
  end

  defp package do
    [
      name: :qh,
      files: ["lib", "mix.exs", "README*", "LICENSE*", "CHANGELOG*"],
      maintainers: ["Robin Fidder"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/fidr/q"}
    ]
  end

  defp docs do
    [
      name: "Q helper",
      source_url: "https://github.com/fidr/qh",
      homepage_url: "https://github.com/fidr/qh",
      main: "readme",
      extras: ["README.md"]
    ]
  end
end
