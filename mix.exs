defmodule Vaartix.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source "https://github.com/vaartix-mail/vaartix-elixir"

  def project do
    [
      app: :vaartix,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "The official Elixir client for Vaartix, the transactional email API built in India.",
      package: [
        licenses: ["MIT"],
        links: %{
          "GitHub" => @source,
          "Docs" => "https://vaartix.com/docs",
          "Website" => "https://vaartix.com"
        },
        files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md)
      ],
      docs: [
        main: "readme",
        extras: ["README.md", "CHANGELOG.md"],
        source_ref: "v#{@version}",
        source_url: @source
      ]
    ]
  end

  def application, do: [extra_applications: [:logger, :crypto]]

  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:plug, "~> 1.15", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
