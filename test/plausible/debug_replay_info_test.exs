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

  @tag :slow
  test "adds replayable sentry context" do
    site = insert(:site)
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

  describe "query tracking" do
    test "track and retrieve queries" do
      :ok = Plausible.DebugReplayInfo.track_query("SELECT * FROM users", "users")
      :ok = Plausible.DebugReplayInfo.track_query("SELECT * FROM accounts", "accounts")

      assert [%{"accounts" => "SELECT * FROM accounts"}, %{"users" => "SELECT * FROM users"}] =
               Plausible.DebugReplayInfo.get_queries_from_context()
    end

    test "carry over context" do
      Sentry.Context.set_user_context(%{id: 1})
      Sentry.Context.set_request_context(%{url: "http://example.com"})
      Sentry.Context.set_extra_context(%{domain: "example.com", site_id: 1})

      test = self()

      sentry_ctx = Sentry.Context.get_all()

      Task.start(fn ->
        Plausible.DebugReplayInfo.carry_over_context(sentry_ctx)
        send(test, {:task_context, Sentry.Context.get_all()})
      end)

      assert_receive {:task_context, ^sentry_ctx}
    end
  end
end
