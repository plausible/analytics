{:ok, _} = Application.ensure_all_started(:ex_machina)
Mox.defmock(Plausible.HTTPClient.Mock, for: Plausible.HTTPClient.Interface)
FunWithFlags.enable(:visits_metric)
Application.ensure_all_started(:double)
Ecto.Adapters.SQL.Sandbox.mode(Plausible.Repo, :manual)

if Plausible.v2?() do
  ExUnit.configure(exclude: [:slow])

  IO.puts("Running tests against v2 schema")
else
  ExUnit.configure(exclude: [:v2_only, :slow])

  IO.puts(
    "Running tests against v1 schema. Use: `V2_MIGRATION_DONE=1 mix test` for secondary run."
  )
end
