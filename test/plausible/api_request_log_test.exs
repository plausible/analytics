defmodule Plausible.ApiRequestLogTest do
  use Plausible.DataCase, async: true

  alias Plausible.ApiRequestLog
  alias Plausible.ApiRequestLog.Entry
  alias Plausible.ApiRequestLog.WriteBuffer

  setup do
    user = new_user(trial_expiry_date: Date.utc_today())
    team = team_of(user)
    api_key = insert(:api_key, user: user, team: team)

    {:ok, user: user, team: team, api_key: api_key}
  end

  describe "record/1" do
    test "records a request made with an API key", %{team: team, api_key: api_key} do
      now = DateTime.utc_now(:second)

      :ok =
        ApiRequestLog.record(%{
          timestamp: DateTime.add(now, 789, :millisecond),
          team: team,
          credential: api_key,
          interface: :rest,
          operation: "POST /api/v2/query",
          status: 200,
          billable: true,
          request_id: "F-request-id",
          user_agent: "python-requests/2.32.3"
        })

      assert_matches [
                       %Entry{
                         timestamp: ^now,
                         team_id: ^team.id,
                         credential_type: "api_key",
                         credential_id: ^api_key.id,
                         interface: "rest",
                         operation: "POST /api/v2/query",
                         status: 200,
                         billable: true,
                         request_id: "F-request-id",
                         user_agent: "python-requests/2.32.3"
                       }
                     ] = recorded_entries(team)
    end

    test "records a request made with an OAuth grant", %{user: user, team: team} do
      grant = insert(:oauth_grant, user: user, team: team)

      :ok =
        ApiRequestLog.record(
          entry_attrs(team, grant, interface: :mcp, operation: "tools/call list_sites")
        )

      assert_matches [
                       %Entry{
                         credential_type: "oauth_grant",
                         credential_id: ^grant.id,
                         interface: "mcp",
                         operation: "tools/call list_sites"
                       }
                     ] = recorded_entries(team)
    end

    test "cuts the user agent to 256 bytes", %{team: team, api_key: api_key} do
      assert recorded_user_agent(team, api_key, String.duplicate("a", 300)) ==
               String.duplicate("a", 256)
    end

    test "drops a user agent character that the 256-byte cut splits", %{
      team: team,
      api_key: api_key
    } do
      assert recorded_user_agent(team, api_key, String.duplicate("a", 255) <> "é") ==
               String.duplicate("a", 255)
    end

    test "drops invalid UTF-8 bytes from the user agent", %{team: team, api_key: api_key} do
      assert recorded_user_agent(team, api_key, "python-requests\xFF") == "python-requests"
    end
  end

  defp entry_attrs(team, credential, overrides) do
    Enum.into(overrides, %{
      timestamp: DateTime.utc_now(),
      team: team,
      credential: credential,
      interface: :rest,
      operation: "POST /api/v2/query",
      status: 200,
      billable: true,
      request_id: "F-request-id",
      user_agent: "python-requests/2.32.3"
    })
  end

  defp recorded_user_agent(team, api_key, user_agent) do
    :ok = ApiRequestLog.record(entry_attrs(team, api_key, user_agent: user_agent))
    [%Entry{user_agent: recorded}] = recorded_entries(team)
    recorded
  end

  defp recorded_entries(team) do
    WriteBuffer.flush()

    from(e in Entry, where: e.team_id == ^team.id)
    |> Plausible.ClickhouseRepo.all()
  end
end
