defmodule Plausible.ApiRequestLogTest do
  use Plausible.DataCase, async: false

  @moduletag :ee_only

  on_ee do
    alias Plausible.ApiRequestLog
    alias Plausible.ApiRequestLog.Entry
    alias Plausible.ApiRequestLog.WriteBuffer

    setup do
      user = new_user(trial_expiry_date: Date.utc_today())
      team = team_of(user)
      api_key = insert(:api_key, user: user, team: team)
      site = new_site(owner: user)
      FunWithFlags.enable(:record_api_requests, for_actor: user)

      {:ok, user: user, team: team, site: site, api_key: api_key}
    end

    describe "record/1" do
      test "records a request made with an API key", %{
        user: user,
        team: team,
        site: site,
        api_key: api_key
      } do
        before_record = DateTime.utc_now(:second)

        :ok =
          ApiRequestLog.record(%{
            team_id: team.id,
            site_id: site.id,
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
                           timestamp: timestamp,
                           team_id: ^team.id,
                           site_id: ^site.id,
                           user_id: ^user.id,
                           credential_type: "api_key",
                           credential_id: ^api_key.id,
                           credential_label: ^api_key.key_prefix,
                           interface: "rest",
                           operation: "POST /api/v2/query",
                           status: 200,
                           billable: true,
                           request_id: "F-request-id",
                           user_agent: "python-requests/2.32.3"
                         }
                       ] = recorded_entries(team)

        assert DateTime.compare(timestamp, before_record) != :lt
      end

      test "records a request made with an OAuth grant", %{user: user, team: team} do
        grant = insert(:oauth_grant, user: user, team: team, client_name: "Claude")

        :ok =
          ApiRequestLog.record(
            entry_attrs(team, grant, interface: :mcp, operation: "tools/call list_sites")
          )

        assert_matches [
                         %Entry{
                           user_id: ^user.id,
                           credential_type: "oauth_grant",
                           credential_id: ^grant.id,
                           credential_label: "Claude",
                           interface: "mcp",
                           operation: "tools/call list_sites"
                         }
                       ] = recorded_entries(team)
      end

      test "labels an OAuth grant without a client name with its client ID", %{
        user: user,
        team: team
      } do
        grant = insert(:oauth_grant, user: user, team: team, client_name: nil)

        :ok = ApiRequestLog.record(entry_attrs(team, grant, []))

        assert [%Entry{credential_label: "https://client.example.com/oauth-metadata"}] =
                 recorded_entries(team)
      end

      test "records site 0 when the request has no site", %{team: team, api_key: api_key} do
        :ok = ApiRequestLog.record(entry_attrs(team, api_key, site_id: nil))

        assert [%Entry{site_id: 0}] = recorded_entries(team)
      end

      test "records team 0 when the team is not known", %{api_key: api_key} do
        :ok = ApiRequestLog.record(entry_attrs(nil, api_key, []))

        assert [%Entry{team_id: 0}] = recorded_entries_of(api_key)
      end

      test "records nothing when the flag is off for the user", %{
        user: user,
        team: team,
        api_key: api_key
      } do
        FunWithFlags.clear(:record_api_requests, for_actor: user)

        :ok = ApiRequestLog.record(entry_attrs(team, api_key, []))

        assert recorded_entries(team) == []
      end

      test "records a 2xx that the caller marks as not billable", %{
        team: team,
        api_key: api_key
      } do
        :ok = ApiRequestLog.record(entry_attrs(team, api_key, status: 200, billable: false))

        assert [%Entry{status: 200, billable: false}] = recorded_entries(team)
      end

      for {field, max_bytes} <- [request_id: 200, user_agent: 256] do
        @field field
        @max_bytes max_bytes

        test "truncates the #{field} to #{max_bytes} bytes", %{team: team, api_key: api_key} do
          assert recorded(team, api_key, @field, String.duplicate("a", 300)) ==
                   String.duplicate("a", @max_bytes)
        end

        test "drops a #{field} character that the #{max_bytes}-byte truncation splits", %{
          team: team,
          api_key: api_key
        } do
          assert recorded(team, api_key, @field, String.duplicate("a", @max_bytes - 1) <> "é") ==
                   String.duplicate("a", @max_bytes - 1)
        end

        test "drops invalid UTF-8 bytes from the #{field}", %{team: team, api_key: api_key} do
          assert recorded(team, api_key, @field, "python-requests\xFF") == "python-requests"
        end
      end
    end

    defp entry_attrs(team, credential, overrides) do
      Enum.into(overrides, %{
        team_id: team && team.id,
        site_id: nil,
        credential: credential,
        interface: :rest,
        operation: "POST /api/v2/query",
        status: 200,
        billable: true,
        request_id: "F-request-id",
        user_agent: "python-requests/2.32.3"
      })
    end

    defp recorded(team, api_key, field, value) do
      :ok = ApiRequestLog.record(entry_attrs(team, api_key, [{field, value}]))
      [entry] = recorded_entries(team)
      Map.fetch!(entry, field)
    end

    defp recorded_entries(team) do
      WriteBuffer.flush()

      from(e in Entry, where: e.team_id == ^team.id)
      |> Plausible.ClickhouseRepo.all()
    end

    defp recorded_entries_of(api_key) do
      WriteBuffer.flush()

      from(e in Entry, where: e.credential_type == "api_key" and e.credential_id == ^api_key.id)
      |> Plausible.ClickhouseRepo.all()
    end
  end
end
