[
  plugins: [Phoenix.LiveView.HTMLFormatter],
  import_deps: [:ecto, :ecto_sql, :phoenix],
  subdirectories: ["priv/*/migrations"],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test,extra}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"],
  locals_without_parens: [
    pageview: 1,
    pageview: 2,
    custom_event: 1,
    custom_event: 2
  ]
]
