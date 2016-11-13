defmodule EZCalendar.Mixfile do
  use Mix.Project

  def project do
    [app: :ez_calendar,
     version: "0.1.2",
     elixir: "~> 1.3",
     elixirc_paths: path(Mix.env),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     package: package,
     description: "A library for building calendars in ecto and phoenix",
     deps: deps()]
  end

  def package do
    [
      maintainers: ["Will Watson"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/willwatson27/ez_calendar"}
    ]
  end


  def application do
    [applications: application(Mix.env)]
  end
  defp application(:test), do: [:postgrex, :logger, :calendar, :ecto]
  defp application(_), do: [:logger, :calendar, :ecto]


  defp path(:test) do
    ["lib", "test/support"]
  end
  defp path(_), do: ["lib"]  

  defp deps do
    [
      {:phoenix_html, "~> 2.7"},
      {:ecto, "~> 2.0"},
      {:calendar, "~> 0.16.1"},

      {:ex_doc, ">= 0.0.0", only: :dev},
      {:postgrex, "~> 0.12.0", only: [:test]}
    ]
  end
end
