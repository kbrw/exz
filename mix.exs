defmodule Mix.Tasks.Compile.NpmJsDom do
  def run(args) do
    if not File.exists?("#{Mix.Project.app_path}/priv/js_dom/node_modules") do
      {_,0} = System.cmd("npm",["install"], cd: "#{Mix.Project.app_path}/priv/js_dom",
                                            into: IO.stream(:stdio, :line))
    end
    :ok
  end
end

defmodule Exz.MixProject do
  use Mix.Project

  def project do
    [
      app: :exz,
      version: "0.1.0",
      elixir: "~> 1.13",
      compilers: Mix.compilers ++ [:npm_js_dom],
      start_permanent: Mix.env() == :prod,
      exz_dir: "test",
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:exos, "~> 2.0"}
    ]
  end
end
