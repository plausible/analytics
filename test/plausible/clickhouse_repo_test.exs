defmodule Plausible.ClickhouseRepoTest do
  use Plausible.DataCase, async: true

  alias Plausible.ClickhouseRepo
  alias Plausible.DebugReplayInfo

  import ExUnit.CaptureLog

  test "queries are kept in context for debugging purposes for superadmins" do
    Sentry.Context.set_user_context(%{id: 1, super_admin?: true})

    ClickhouseRepo.all(from(u in "events_v2", select: true, limit: 0))

    ClickhouseRepo.one(from(u in "events_v2", select: true, limit: 0),
      label: "one"
    )

    queries = DebugReplayInfo.get_queries_from_context()

    assert [
             %{"one" => "SELECT true FROM \"events_v2\" AS e0 LIMIT 0"},
             %{"unlabelled" => "SELECT true FROM \"events_v2\" AS e0 LIMIT 0"}
           ] = queries
  end

  test "queries are not kept in context for debugging purposes for non-superadmins" do
    ClickhouseRepo.all(from(u in "events_v2", select: true, limit: 0))

    ClickhouseRepo.one(from(u in "events_v2", select: true, limit: 0),
      label: "one"
    )

    assert DebugReplayInfo.get_queries_from_context() == []
  end

  test "queries are logged with sentry and extra metadata" do
    Sentry.Context.set_user_context(%{id: 1})
    Sentry.Context.set_request_context(%{url: "http://example.com"})
    Sentry.Context.set_extra_context(%{domain: "example.com", site_id: 1})

    ClickhouseRepo.all(from(u in "sessions_v2", select: true, limit: 0),
      label: "log_all"
    )

    ClickhouseRepo.one(from(u in "sessions_v2", select: true, limit: 0),
      label: "log_one",
      metadata: %{"metric" => "value"}
    )

    flush_clickhouse_logs()

    assert %{
             rows: [
               [q1, c1],
               [q2, c2]
             ]
           } =
             ClickhouseRepo.query!("""
             SELECT
             query,
             log_comment
             FROM system.query_log
             WHERE (type = 1) AND (query LIKE '%sessions_v2%')
             AND JSONExtractString(log_comment, 'label') IN ('log_all', 'log_one')
             ORDER BY event_time DESC
             LIMIT 2
             """)

    assert q1 == "SELECT true FROM \"sessions_v2\" AS s0 LIMIT 0"
    assert q1 == q2

    assert Enum.find([c1, c2], fn c ->
             Jason.decode!(c) == %{
               "label" => "log_all",
               "domain" => "example.com",
               "url" => "http://example.com",
               "user_id" => 1,
               "metadata" => %{},
               "site_id" => 1
             }
           end)

    assert Enum.find([c1, c2], fn c ->
             Jason.decode!(c) == %{
               "label" => "log_one",
               "domain" => "example.com",
               "url" => "http://example.com",
               "user_id" => 1,
               "metadata" => %{"metric" => "value"},
               "site_id" => 1
             }
           end)
  end

  test "non-serializable log comment won't cause the query to crash and will log an error" do
    log =
      capture_log(fn ->
        assert [] =
                 ClickhouseRepo.all(from(u in "sessions_v2", select: true, limit: 0),
                   label: "log_all",
                   metadata: {:error, :skip_me}
                 )
      end)

    assert log =~
             ~s/Failed to include log comment: %{label: "log_all", domain: nil, metadata: {:error, :skip_me}, url: nil, site_id: nil, user_id: nil}/
  end

  defp flush_clickhouse_logs(), do: Plausible.IngestRepo.query!("SYSTEM FLUSH LOGS")
end
