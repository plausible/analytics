defmodule Plausible.ClickhouseRepoTest do
  use Plausible.DataCase, async: true

  test "queries are kept in context for debugging purposes for superadmins" do
    Sentry.Context.set_user_context(%{id: 1, super_admin?: true})

    Plausible.ClickhouseRepo.all(from(u in "events_v2", select: true, limit: 0))

    Plausible.ClickhouseRepo.one(from(u in "events_v2", select: true, limit: 0),
      debug_label: "one"
    )

    queries = Plausible.DebugReplayInfo.get_queries_from_context()

    assert [
             %{"one" => "SELECT true FROM \"events_v2\" AS e0 LIMIT 0"},
             %{"unlabelled" => "SELECT true FROM \"events_v2\" AS e0 LIMIT 0"}
           ] = queries
  end

  test "queries are not kept in context for debugging purposes for non-superadmins" do
    Plausible.ClickhouseRepo.all(from(u in "events_v2", select: true, limit: 0))

    Plausible.ClickhouseRepo.one(from(u in "events_v2", select: true, limit: 0),
      debug_label: "one"
    )

    assert Plausible.DebugReplayInfo.get_queries_from_context() == []
  end

  test "queries are logged with sentry metadata" do
    Sentry.Context.set_user_context(%{id: 1})
    Sentry.Context.set_request_context(%{url: "http://example.com"})
    Sentry.Context.set_extra_context(%{domain: "example.com", site_id: 1})

    Plausible.ClickhouseRepo.all(from(u in "sessions_v2", select: true, limit: 0),
      debug_label: "log_all"
    )

    Plausible.ClickhouseRepo.one(from(u in "sessions_v2", select: true, limit: 0),
      debug_label: "log_one"
    )

    assert [
             [q1, c1],
             [q2, c2]
           ] =
             eventually(
               fn ->
                 result =
                   Plausible.ClickhouseRepo.query!("""
                   SELECT
                   query,
                   log_comment
                   FROM system.query_log
                   WHERE (type = 1) AND (query LIKE '%sessions_v2%')
                   AND JSONExtractString(log_comment, 'debug_label') IN ('log_all', 'log_one')
                   ORDER BY event_time DESC
                   LIMIT 2
                   """)

                 {length(result.rows) == 2, result.rows}
               end,
               500,
               10
             )

    assert q1 == "SELECT true FROM \"sessions_v2\" AS s0 LIMIT 0"
    assert q1 == q2

    assert Enum.find([c1, c2], fn c ->
             Jason.decode!(c) == %{
               "debug_label" => "log_all",
               "domain" => "example.com",
               "url" => "http://example.com",
               "user_id" => 1
             }
           end)

    assert Enum.find([c1, c2], fn c ->
             Jason.decode!(c) == %{
               "debug_label" => "log_one",
               "domain" => "example.com",
               "url" => "http://example.com",
               "user_id" => 1
             }
           end)
  end
end
