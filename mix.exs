defmodule Plausible.MixProject do
  use Mix.Project

  def project do
    [
      app: :plausible,
      version: System.get_env("APP_VERSION", "0.0.1"),
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [
        tool: ExCoveralls
      ],
      releases: [
        plausible: [
          include_executables_for: [:unix],
          applications: [plausible: :permanent],
          steps: [:assemble, :tar]
        ]
      ],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix, :ex_unit]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Plausible.Application, []},
      extra_applications: [
        :logger,
        :runtime_tools
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 2.0"},
      {:combination, "~> 0.0.3"},
      {:cors_plug, "~> 2.0"},
      {:ecto_sql, "~> 3.0"},
      {:elixir_uuid, "~> 1.2", only: :test},
      {:jason, "~> 1.2"},
      {:phoenix, "~> 1.5.0"},
      {:phoenix_ecto, "~> 4.0"},
      {:phoenix_html, "~> 2.12"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_pubsub, "~> 2.0"},
      {:plug_cowboy, "~> 2.3"},
      {:postgrex, ">= 0.0.0"},
      {:ref_inspector, "~> 1.3"},
      {:timex, "~> 3.6"},
      {:ua_inspector, "~> 3.0"},
      {:bamboo, "~> 2.2"},
      {:hackney, "~> 1.8"},
      {:bamboo_phoenix, "~> 1.0.0"},
      {:bamboo_postmark, git: "https://github.com/pablo-co/bamboo_postmark.git", tag: "master"},
      {:bamboo_smtp, "~> 4.1"},
      {:sentry, "~> 8.0"},
      {:httpoison, "~> 1.4"},
      {:ex_machina, "~> 2.3", only: :test},
      {:excoveralls, "~> 0.10", only: :test},
      {:double, "~> 0.8.0", only: :test},
      {:php_serializer, "~> 2.0"},
      {:csv, "~> 2.3"},
      {:oauther, "~> 1.3"},
      {:nanoid, "~> 2.0.2"},
      {:siphash, "~> 3.2"},
      {:oban, "~> 2.0"},
      {:geolix, "~> 1.0"},
      {:clickhouse_ecto, git: "https://github.com/plausible/clickhouse_ecto.git"},
      {:location, git: "https://github.com/plausible/location.git"},
      {:geolix_adapter_mmdb2, "~> 0.5.0"},
      {:cachex, "~> 3.4"},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:kaffy, "~> 0.9.0"},
      {:envy, "~> 1.1.1"},
      {:phoenix_pagination, "~> 0.7.0"},
      {:hammer, "~> 6.0"},
      {:public_suffix, git: "https://github.com/axelson/publicsuffix-elixir"},
      {:floki, "~> 0.32.0", only: :test},
      {:referrer_blocklist, git: "https://github.com/plausible/referrer-blocklist.git"}
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test", "clean_clickhouse"],
      sentry_recompile: ["compile", "deps.compile sentry --force"]
    ]
  end
end
