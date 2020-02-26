{:ok, _} = Application.ensure_all_started(:ex_machina)
ExUnit.start()
Application.ensure_all_started(:double)
Ecto.Adapters.SQL.Sandbox.mode(Plausible.Repo, :manual)
