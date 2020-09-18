defmodule Debounce.Mixfile do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :debounce,
      version: @version,
      elixir: "~> 1.6",
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
    [
      {:ex_doc, "~> 0.14", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Michał Muskała"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/michalmuskala/debounce"}
    ]
  end

  defp docs do
    [
      main: "Debounce",
      name: "Debounce",
      source_ref: "v#{@version}",
      source_url: "https://github.com/michalmuskala/debounce",
    ]
  end
end
