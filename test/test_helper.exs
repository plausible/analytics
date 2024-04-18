if not Enum.empty?(Path.wildcard("lib/**/*_test.exs")) do
  raise "Oops, test(s) found in `lib/` directory. Move them to `test/`."
end

{:ok, _} = Application.ensure_all_started(:ex_machina)
Mox.defmock(Plausible.HTTPClient.Mock, for: Plausible.HTTPClient.Interface)
Application.ensure_all_started(:double)
FunWithFlags.enable(:imports_exports)
FunWithFlags.enable(:csv_imports_exports)

# Temporary flag to test `experimental_reduced_joins` flag on all tests.
if System.get_env("TEST_EXPERIMENTAL_REDUCED_JOINS") == "1" do
  FunWithFlags.enable(:experimental_reduced_joins)
else
  FunWithFlags.disable(:experimental_reduced_joins)
end

Ecto.Adapters.SQL.Sandbox.mode(Plausible.Repo, :manual)

# warn about minio if it's included in tests but not running
if :minio in Keyword.fetch!(ExUnit.configuration(), :include) do
  Plausible.TestUtils.ensure_minio()
end

if Mix.env() == :small_test do
  IO.puts("Test mode: SMALL")
  ExUnit.configure(exclude: [:slow, :minio, :full_build_only])
else
  IO.puts("Test mode: FULL")
  ExUnit.configure(exclude: [:slow, :minio, :small_build_only])
end
