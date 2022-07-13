defmodule Exz.MixProject do
  use Mix.Project

  def project do
    [
      app: :exz,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      exz_dir: "test",
      deps: deps()
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
      {:exos, "~> 2.0"}
    ]
  end
end
