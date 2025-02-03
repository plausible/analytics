defmodule Plausible.MixProject do
  use Mix.Project

  def project do
    [
      name: "Plausible",
      source_url: "https://github.com/plausible/analytics",
      docs: docs(),
      app: :plausible,
      version: System.get_env("APP_VERSION", "0.0.1"),
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() in [:prod, :ce],
      aliases: aliases(),
      deps: deps(),
      test_coverage: [
        tool: ExCoveralls
      ],
      releases: [
        plausible: [
          include_executables_for: [:unix],
          config_providers: [
            {Config.Reader,
             path: {:system, "RELEASE_ROOT", "/import_extra_config.exs"}, imports: []}
          ]
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
        :tls_certificate_check,
        :opentelemetry_exporter
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(env) when env in [:test, :dev],
    do: ["lib", "test/support", "extra/lib"]

  defp elixirc_paths(env) when env in [:ce_test, :ce_dev],
    do: ["lib", "test/support"]

  defp elixirc_paths(:ce), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "extra/lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bamboo, "~> 2.3", override: true},
      {:bamboo_postmark, git: "https://github.com/plausible/bamboo_postmark.git", branch: "main"},
      {:bamboo_smtp, "~> 4.1"},
      {:bamboo_mua, "~> 0.2.0"},
      {:bcrypt_elixir, "~> 3.0"},
      {:bypass, "~> 2.1", only: [:dev, :test, :ce_test]},
      {:ecto_ch, "~> 0.5.0"},
      {:cloak, "~> 1.1"},
      {:cloak_ecto, "~> 1.2"},
      {:combination, "~> 0.0.3"},
      {:cors_plug, "~> 3.0"},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:double, "~> 0.8.0", only: [:test, :ce_test]},
      {:ecto, "~> 3.12.0"},
      {:ecto_sql, "~> 3.12.0"},
      {:envy, "~> 1.1.1"},
      {:eqrcode, "~> 0.1.10"},
      {:ex_machina, "~> 2.3", only: [:dev, :test, :ce_dev, :ce_test]},
      {:excoveralls, "~> 0.10", only: :test},
      {:finch, "~> 0.17.0"},
      {:floki, "~> 0.36"},
      {:fun_with_flags, "~> 1.11.0"},
      {:fun_with_flags_ui, "~> 1.0"},
      {:locus, "~> 2.3"},
      {:gen_cycle, "~> 1.0.4"},
      {:hackney, "~> 1.8"},
      {:jason, "~> 1.3"},
      {:kaffy, "~> 0.10.2", only: [:dev, :test, :staging, :prod]},
      {:location, git: "https://github.com/plausible/location.git"},
      {:mox, "~> 1.0", only: [:test, :ce_test]},
      {:nanoid, "~> 2.1.0"},
      {:nimble_totp, "~> 1.0"},
      {:oban, "~> 2.17.0"},
      {:observer_cli, "~> 1.7"},
      {:opentelemetry, "~> 1.1"},
      {:opentelemetry_api, "~> 1.1"},
      {:opentelemetry_ecto, "~> 1.1.0"},
      {:opentelemetry_exporter, "~> 1.6.0"},
      {:opentelemetry_phoenix, "~> 1.0"},
      {:opentelemetry_oban, "~> 1.0.0"},
      {:phoenix, "~> 1.7.0"},
      {:phoenix_view, "~> 2.0"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: [:dev, :ce_dev]},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_live_view, "~> 1.0"},
      {:php_serializer, "~> 2.0"},
      {:plug, "~> 1.13", override: true},
      {:plug_cowboy, "~> 2.3"},
      {:postgrex, "~> 0.19.0"},
      {:prom_ex, "~> 1.8"},
      {:public_suffix, git: "https://github.com/axelson/publicsuffix-elixir"},
      {:ref_inspector, "~> 2.0"},
      {:referrer_blocklist, git: "https://github.com/plausible/referrer-blocklist.git"},
      {:sentry, "~> 10.0"},
      {:siphash, "~> 3.2"},
      {:timex, "~> 3.7"},
      {:ua_inspector,
       git: "https://github.com/plausible/ua_inspector.git", branch: "sanitize-pre"},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:ex_money, "~> 5.12"},
      {:mjml_eex, "~> 0.11.0"},
      {:mjml, "~> 3.1.0"},
      {:heroicons, "~> 0.5.0"},
      {:zxcvbn, git: "https://github.com/techgaun/zxcvbn-elixir.git"},
      {:open_api_spex, "~> 3.18"},
      {:joken, "~> 2.5"},
      {:paginator, git: "https://github.com/duffelhq/paginator.git"},
      {:scrivener_ecto, "~> 2.0"},
      {:esbuild, "~> 0.7", runtime: Mix.env() in [:dev, :ce_dev]},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() in [:dev, :ce_dev]},
      {:ex_json_logger, "~> 1.4.0"},
      {:ecto_network, "~> 1.5.0"},
      {:ex_aws, "~> 2.5"},
      {:ex_aws_s3, "~> 2.5"},
      {:sweet_xml, "~> 0.7.4"},
      {:zstream, "~> 0.6.4"},
      {:con_cache, "~> 1.1.1"},
      {:req, "~> 0.5.0"},
      {:happy_tcp, github: "ruslandoga/happy_tcp", only: [:ce, :ce_dev, :ce_test]},
      {:ex_json_schema, "~> 0.10.2"},
      {:odgn_json_pointer, "~> 3.0.1"},
      {:phoenix_bakery, "~> 0.1.2", only: [:ce, :ce_dev, :ce_test]},
      {:site_encrypt, github: "sasa1977/site_encrypt", only: [:ce, :ce_dev, :ce_test]},
      {:phoenix_storybook, "~> 0.8"},
      {:unzip, "~> 0.12", only: [:test, :ce_test]}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test", "clean_clickhouse"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.typecheck": ["cmd npm --prefix assets run typecheck"],
      "assets.build": [
        "tailwind default",
        "tailwind storybook",
        "esbuild default"
      ],
      "assets.deploy": [
        "tailwind default --minify",
        "tailwind storybook --minify",
        "esbuild default --minify",
        "phx.digest"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      logo: "priv/static/images/ee/favicon-32x32.png",
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
