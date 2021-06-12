defmodule TzExtra.MixProject do
  use Mix.Project

  @version "0.16.7"

  def project do
    [
      app: :tz_extra,
      elixir: "~> 1.9",
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),

      # Hex
      version: @version,
      package: package(),
      description: "Time zone-related utilities",

      # ExDoc
      name: "TzExtra",
      source_url: "https://github.com/mathieuprog/tz_extra",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:tz, "~> 0.16"},
      {:ecto, "~> 3.6", optional: true},
      {:jason, "~> 1.1", only: :dev},
      {:ex_doc, "~> 0.21", only: :dev}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      licenses: ["Apache 2.0"],
      maintainers: ["Mathieu Decaffmeyer"],
      links: %{"GitHub" => "https://github.com/mathieuprog/tz_extra"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}"
    ]
  end
end
