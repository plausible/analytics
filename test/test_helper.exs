if not Enum.empty?(Path.wildcard("lib/**/*_test.exs")) do
  raise "Oops, test(s) found in `lib/` directory. Move them to `test/`."
end

if Mix.env() == :e2e_test do
  Application.put_env(:wallaby, :base_url, PlausibleWeb.Endpoint.url())
  {:ok, _} = Application.ensure_all_started(:wallaby)
else
  {:ok, _} = Application.ensure_all_started(:ex_machina)
  Mox.defmock(Plausible.HTTPClient.Mock, for: Plausible.HTTPClient.Interface)

  Mox.defmock(Plausible.DnsLookup.Mock,
    for: Plausible.DnsLookupInterface
  )

  Application.ensure_all_started(:double)

  Ecto.Adapters.SQL.Sandbox.mode(Plausible.Repo, :manual)
end

# warn about minio if it's included in tests but not running
if :minio in Keyword.fetch!(ExUnit.configuration(), :include) do
  Plausible.TestUtils.ensure_minio()
end

default_exclude = [:slow, :minio, :migrations]

# avoid slowdowns contacting the code server
for {app, _, _} <- Application.loaded_applications() do
  if modules = Application.spec(app, :modules) do
    Code.ensure_all_loaded(modules)
  end
end

case Mix.env() do
  :ce_test ->
    IO.puts("Test mode: Community Edition")
    ExUnit.configure(exclude: [:ee_only, :e2e | default_exclude])

  :e2e_test ->
    IO.puts("Test mode: End-to-End Tests")
    ExUnit.configure(exclude: [:test], include: [:e2e])

  _ ->
    IO.puts("Test mode: Enterprise Edition")
    ExUnit.configure(exclude: [:ce_build_only, :e2e | default_exclude])
end
