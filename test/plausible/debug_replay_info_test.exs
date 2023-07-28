defmodule Plausible.DebugReplayInfoTest do
  use Plausible.DataCase, async: true

  defmodule SampleModule do
    use Plausible.DebugReplayInfo

    def task(site, query, report_to) do
      include_sentry_replay_info()
      send(report_to, {:task_done, Sentry.Context.get_all()})
      {:ok, {site, query}}
    end
  end

  test "adds replayable sentry context" do
    site = build(:site)
    query = Plausible.Stats.Query.from(site, %{"period" => "day"})
    {:ok, {^site, ^query}} = SampleModule.task(site, query, self())

    assert_receive {:task_done, context}

    assert is_integer(context.extra.debug_replay_info_size)
    assert info = context.extra.debug_replay_info

    {function, input} = Plausible.DebugReplayInfo.deserialize(info)

    assert function == (&SampleModule.task/3)

    assert input[:site] == site
    assert input[:query] == query
    assert input[:report_to] == self()

    assert apply(function, [input[:site], input[:query], input[:report_to]])
    assert_receive {:task_done, ^context}
  end

  test "won't add replay info, if serialized input too large" do
    {:ok, _} =
      SampleModule.task(
        :crypto.strong_rand_bytes(10_000),
        :crypto.strong_rand_bytes(10_000),
        self()
      )

    assert_receive {:task_done, context}
    assert context.extra.debug_replay_info == :too_large
    assert context.extra.debug_replay_info_size > 10_000
  end
end
