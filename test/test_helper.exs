{:ok, _} = Application.ensure_all_started(:ex_machina)
Mox.defmock(Plausible.HTTPClient.Mock, for: Plausible.HTTPClient.Interface)
Application.ensure_all_started(:double)
FunWithFlags.enable(:window_time_on_page)
FunWithFlags.enable(:imports_exports)
FunWithFlags.enable(:shield_pages)
Ecto.Adapters.SQL.Sandbox.mode(Plausible.Repo, :manual)

if Mix.env() == :ce_test do
  IO.puts("Test mode: Community Edition")
  ExUnit.configure(exclude: [:slow, :minio, :ee_only])
else
  IO.puts("Test mode: Enterprise Edition")
  ExUnit.configure(exclude: [:slow, :minio, :ce_build_only])
end
