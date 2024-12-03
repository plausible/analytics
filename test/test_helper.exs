if not Enum.empty?(Path.wildcard("lib/**/*_test.exs")) do
  raise "Oops, test(s) found in `lib/` directory. Move them to `test/`."
end

{:ok, _} = Application.ensure_all_started(:ex_machina)
Mox.defmock(Plausible.HTTPClient.Mock, for: Plausible.HTTPClient.Interface)
Application.ensure_all_started(:double)

FunWithFlags.enable(:channels)
FunWithFlags.enable(:scroll_depth)
FunWithFlags.enable(:read_team_schemas)

Ecto.Adapters.SQL.Sandbox.mode(Plausible.Repo, :manual)

# warn about minio if it's included in tests but not running
if :minio in Keyword.fetch!(ExUnit.configuration(), :include) do
  Plausible.TestUtils.ensure_minio()
end

default_exclude = [:slow, :minio, :migrations]

# avoid slowdowns contacting the code server https://github.com/sasa1977/con_cache/pull/79
:code.ensure_loaded(ConCache.Lock.Resource)

if Mix.env() == :ce_test do
  IO.puts("Test mode: Community Edition")
  ExUnit.configure(exclude: [:ee_only | default_exclude])
else
  IO.puts("Test mode: Enterprise Edition")
  ExUnit.configure(exclude: [:ce_build_only | default_exclude])
end
