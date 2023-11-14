[
  plugins: [Phoenix.LiveView.HTMLFormatter],
  import_deps: [:ecto, :ecto_sql, :phoenix],
  subdirectories: ["priv/*/migrations"],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test,bench}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"]
]
