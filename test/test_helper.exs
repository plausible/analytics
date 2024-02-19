{:ok, _} = Application.ensure_all_started(:ex_machina)
Mox.defmock(Plausible.HTTPClient.Mock, for: Plausible.HTTPClient.Interface)
Application.ensure_all_started(:double)
FunWithFlags.enable(:window_time_on_page)
FunWithFlags.enable(:shields)
Ecto.Adapters.SQL.Sandbox.mode(Plausible.Repo, :manual)

if Mix.env() == :small_test do
  IO.puts("Test mode: SMALL")
  ExUnit.configure(exclude: [:slow, :minio, :full_build_only])
else
  IO.puts("Test mode: FULL")
  ExUnit.configure(exclude: [:slow, :minio, :small_build_only])
end
