defmodule Plausible.MixProject do
  use Mix.Project

  def project do
    [
      name: "Plausible",
      source_url: "https://github.com/plausible/analytics",
      docs: docs(),
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
        :runtime_tools,
        :tls_certificate_check
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
      {:bamboo, "~> 2.2"},
      {:bamboo_phoenix, "~> 1.0.0"},
      {:bamboo_postmark, git: "https://github.com/pablo-co/bamboo_postmark.git", tag: "master"},
      {:bamboo_smtp, "~> 4.1"},
      {:bcrypt_elixir, "~> 2.0"},
      {:bypass, "~> 2.1", only: [:dev, :test]},
      {:cachex, "~> 3.4"},
      {:clickhouse_ecto, git: "https://github.com/plausible/clickhouse_ecto.git"},
      {:combination, "~> 0.0.3"},
      {:connection, "~> 1.1", override: true},
      {:cors_plug, "~> 3.0"},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:csv, "~> 2.3"},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:double, "~> 0.8.0", only: :test},
      {:ecto_sql, "~> 3.0"},
      {:elixir_uuid, "~> 1.2", only: :test},
      {:envy, "~> 1.1.1"},
      {:ex_machina, "~> 2.3", only: :test},
      {:excoveralls, "~> 0.10", only: :test},
      {:exvcr, "~> 0.11", only: :test},
      {:finch, "~> 0.12.0", override: true},
      {:floki, "~> 0.32.0", only: :test},
      {:fun_with_flags, "~> 1.9.0"},
      {:fun_with_flags_ui, "~> 0.8"},
      {:geolix, "~> 2.0"},
      {:geolix_adapter_mmdb2, "~> 0.6.0"},
      {:hackney, "~> 1.8"},
      {:hammer, "~> 6.0"},
      {:httpoison, "~> 1.4"},
      {:jason, "~> 1.3"},
      {:kaffy, "~> 0.9.0"},
      {:location, git: "https://github.com/plausible/location.git"},
      {:mimic, "~> 1.7", only: :test},
      {:mox, "~> 1.0", only: :test},
      {:nanoid, "~> 2.0.2"},
      {:oauther, "~> 1.3"},
      {:oban, "~> 2.11"},
      {:observer_cli, "~> 1.7"},
      {:opentelemetry, "~> 1.0"},
      {:opentelemetry_api, "~> 1.0"},
      {:opentelemetry_ecto, "~> 1.0.0"},
      {:opentelemetry_exporter, "~> 1.0"},
      {:opentelemetry_phoenix, "~> 1.0"},
      {:phoenix, "~> 1.6.0"},
      {:phoenix_ecto, "~> 4.0"},
      {:phoenix_html, "~> 2.12"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_pagination, "~> 0.7.0"},
      {:phoenix_pubsub, "~> 2.0"},
      {:php_serializer, "~> 2.0"},
      {:plug, "~> 1.13", override: true},
      {:plug_cowboy, "~> 2.3"},
      {:prom_ex, "~> 1.7.1"},
      {:public_suffix, git: "https://github.com/axelson/publicsuffix-elixir"},
      {:ref_inspector, "~> 1.3"},
      {:referrer_blocklist, git: "https://github.com/plausible/referrer-blocklist.git"},
      {:sentry, "~> 8.0"},
      {:siphash, "~> 3.2"},
      {:telemetry, "~> 1.0", override: true},
      {:timex, "~> 3.7"},
      {:ua_inspector, "~> 3.0"},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false}
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

  defp docs do
    [
      main: "readme",
      logo: "assets/static/images/icon/plausible_favicon.png",
      extras:
        Path.wildcard("guides/**/*.md") ++
          [
            "README.md": [filename: "readme", title: "Introduction"],
            "CONTRIBUTING.md": [filename: "contributing", title: "Contributing"]
          ],
      groups_for_extras: [
        Features: Path.wildcard("guides/features/*.md")
      ],
      before_closing_body_tag: fn
        :html ->
          """
          <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
          <script>mermaid.initialize({startOnLoad: true})</script>
          """

        _ ->
          ""
      end
    ]
  end
end
