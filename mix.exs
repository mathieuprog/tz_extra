defmodule TzExtra.MixProject do
  use Mix.Project

  @version "0.27.0"

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
      {:tz, "~> 0.26"},
      {:ecto, "~> 3.11", optional: true},
      {:jason, "~> 1.4", only: :dev},
      {:ex_doc, "~> 0.34", only: :dev}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      licenses: ["Apache-2.0"],
      maintainers: ["Mathieu Decaffmeyer"],
      links: %{
        "GitHub" => "https://github.com/mathieuprog/tz_extra",
        "Sponsor" => "https://github.com/sponsors/mathieuprog"
      }
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
