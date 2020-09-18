defmodule Debounce.Mixfile do
  use Mix.Project

  def project do
    [
      app: :debounce,
      version: "0.1.1",
      elixir: "~> 1.3",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "A process-based debouncer for Elixir",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [], mod: {Debounce.Application, []}]
  end

  defp deps do
    [{:ex_doc, "~> 0.14", only: :dev}]
  end

  defp package do
    [
      maintainers: ["Michał Muskała"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/michalmuskala/debounce"}
    ]
  end

  defp docs do
    [main: "Debounce"]
  end
end
