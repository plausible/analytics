defmodule Plausible.MixProject do
  use Mix.Project

  def project do
    [
      app: :plausible,
      version: System.get_env("APP_VERSION", "0.0.1"),
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
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
        :sentry,
        :runtime_tools,
        :timex,
        :ua_inspector,
        :ref_inspector,
        :bamboo,
        :bamboo_smtp
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
      # remove
      {:browser, "~> 0.4.3"},
      {:bcrypt_elixir, "~> 2.0"},
      {:cors_plug, "~> 1.5"},
      {:ecto_sql, "~> 3.0"},
      {:elixir_uuid, "~> 1.2"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:phoenix, "~> 1.4.0"},
      {:phoenix_ecto, "~> 4.0"},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_pubsub, "~> 1.1"},
      {:plug_cowboy, "~> 2.0"},
      {:postgrex, ">= 0.0.0"},
      #  Used in paddle_api, can remove
      {:poison, "~> 3.1"},
      {:ref_inspector, "~> 1.3"},
      {:timex, "~> 3.6"},
      {:ua_inspector, "~> 0.18"},
      {:bamboo, "~> 1.3"},
      {:bamboo_postmark, "~> 0.5"},
      {:bamboo_smtp, "~> 2.1.0"},
      {:sentry, "~> 7.0"},
      {:httpoison, "~> 1.4"},
      {:ex_machina, "~> 2.3", only: :test},
      {:excoveralls, "~> 0.10", only: :test},
      {:double, "~> 0.7.0", only: :test},
      {:junit_formatter, "~> 3.1", only: [:test]},
      {:php_serializer, "~> 0.9.0"},
      {:csv, "~> 2.3"},
      {:oauther, "~> 1.1"},
      {:nanoid, "~> 2.0.2"},
      {:siphash, "~> 3.2"},
      {:oban, "~> 1.2"},
      {:sshex, "2.2.1"},
      {:geolix, "~> 1.0"},
      {:clickhouse_ecto, git: "https://github.com/plausible/clickhouse_ecto.git"},
      {:geolix_adapter_mmdb2, "~> 0.5.0"},
      {:logflare_logger_backend, "~> 0.7.6"},
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test", "clean_clickhouse"]
    ]
  end
end
