defmodule Debounce.Mixfile do
  use Mix.Project

  def project do
    [app: :debounce,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [extra_applications: [],
     mod: {Debounce.Application, []}]
  end

  defp deps do
    []
  end
end
