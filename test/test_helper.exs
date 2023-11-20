{:ok, _} = Application.ensure_all_started(:ex_machina)
Mox.defmock(Plausible.HTTPClient.Mock, for: Plausible.HTTPClient.Interface)
Application.ensure_all_started(:double)
FunWithFlags.enable(:business_tier)
FunWithFlags.enable(:window_time_on_page)
Ecto.Adapters.SQL.Sandbox.mode(Plausible.Repo, :manual)

if Mix.env() == :small_test do
  ExUnit.configure(exclude: [:slow, :full_build_only])
else
  ExUnit.configure(exclude: [:slow, :small_build_only])
end
