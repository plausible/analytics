Benchee.init([])
|> Benchee.system()
|> Map.fetch!(:system)
|> Enum.each(fn {k, v} -> IO.inspect(v, label: k) end)

Plausible.IngestRepo.query!("truncate events_v2")

event = %Plausible.ClickhouseEventV2{
  name: "pageview",
  site_id: 3,
  hostname: "dummy.site",
  pathname: "/some-page",
  user_id: 6_744_441_728_453_009_796,
  session_id: 5_760_370_699_094_039_040,
  timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
  country_code: "KR",
  city_geoname_id: 123,
  screen_size: "Desktop",
  operating_system: "Mac",
  operating_system_version: "10.15",
  browser: "Opera",
  browser_version: "71.0"
}

measured = fn name, f ->
  started_at = System.monotonic_time(:millisecond)
  result = f.()
  it_took = System.monotonic_time(:millisecond) - started_at
  IO.puts("finished #{name} in #{it_took}ms")
  result
end

# TODO
:code.add_path(:code.root_dir() ++ ~c"/lib/tools-3.6/ebin")
:ok = Application.load(:tools)
profile? = System.get_env("EPROF") || System.get_env("PROFILE")
if profile?, do: :eprof.start_profiling([Process.whereis(Plausible.Event.WriteBuffer)])

measured.("insert into buffer", fn ->
  1..1_000_000
  |> Task.async_stream(
    fn _ -> Plausible.Event.WriteBuffer.insert(event) end,
    max_concurrency: 100,
    ordered: false
  )
  |> Stream.run()
end)

IO.puts(
  "message queue length #{Plausible.Event.WriteBuffer |> Process.whereis() |> Process.info(:message_queue_len) |> elem(1)} after insert and before flush"
)

measured.("flushed", fn -> Plausible.Event.WriteBuffer.flush() end)
IO.puts("inserted #{Plausible.ClickhouseRepo.aggregate("events_v2", :count)} events")

if profile? do
  :eprof.stop_profiling()
  :eprof.analyze()
end
