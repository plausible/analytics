defmodule PlausibleWeb.SettingsController.ConnectedAppsTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Repo

  alias PlausibleWeb.TextHelpers

  describe "DELETE /settings/connected-apps/:id" do
    setup [:create_user, :log_in, :create_team]

    setup %{user: user} do
      FunWithFlags.enable(:mcp, for_actor: user)
      :ok
    end

    test "returns 404 without the feature flag", %{conn: conn, user: user, team: team} do
      FunWithFlags.disable(:mcp, for_actor: user)
      grant = insert(:oauth_grant, user: user, team: team)

      conn = delete(conn, ~p"/settings/connected-apps/#{grant.id}")

      assert html_response(conn, 404)
      refute Repo.reload!(grant).revoked_at
    end

    test "revokes the grant", %{conn: conn, user: user, team: team} do
      grant = insert(:oauth_grant, user: user, team: team)

      conn = delete(conn, ~p"/settings/connected-apps/#{grant.id}")

      assert redirected_to(conn, 302) == ~p"/settings/connected-apps#connected-apps"
      assert Phoenix.Flash.get(conn.assigns.flash, :success) == "Access revoked successfully"
      assert Repo.reload!(grant).revoked_at
    end

    test "user can't revoke a grant that doesn't belong to them", %{conn: conn, team: team} do
      other_user = add_member(team, role: :editor)
      grant = insert(:oauth_grant, user: other_user, team: team)

      conn = delete(conn, ~p"/settings/connected-apps/#{grant.id}")

      assert redirected_to(conn, 302) == ~p"/settings/connected-apps#connected-apps"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Could not find connected app to revoke"

      refute Repo.reload!(grant).revoked_at
    end
  end

  describe "GET /settings/connected-apps" do
    setup [:create_user, :log_in, :create_team]

    setup %{user: user} do
      FunWithFlags.enable(:mcp, for_actor: user)
      :ok
    end

    test "returns 404 without the feature flag", %{conn: conn, user: user} do
      FunWithFlags.disable(:mcp, for_actor: user)

      conn = get(conn, ~p"/settings/connected-apps")

      assert html_response(conn, 404)
    end

    test "shows an empty state", %{conn: conn} do
      conn = get(conn, ~p"/settings/connected-apps")

      assert html = html_response(conn, 200)
      assert html =~ "No connected apps"
    end

    test "lists the user's grants, most recently used first", %{
      conn: conn,
      user: user,
      team: team
    } do
      now = NaiveDateTime.utc_now(:second)
      yesterday = NaiveDateTime.add(now, -1, :day)

      named_grant =
        insert(:oauth_grant,
          user: user,
          team: team,
          client_name: "Claude",
          inserted_at: yesterday,
          last_used_at: NaiveDateTime.add(now, -5, :hour)
        )

      unnamed_grant =
        insert(:oauth_grant,
          user: user,
          team: team,
          client_name: nil,
          inserted_at: now
        )

      revoked_grant =
        insert(:oauth_grant,
          client_name: "revoked grant",
          user: user,
          team: team,
          revoked_at: now
        )

      expired_grant =
        insert(:oauth_grant,
          client_name: "expired grant",
          user: user,
          team: team,
          refresh_token_expires_at: yesterday
        )

      other_user = add_member(team, role: :editor)

      other_user_grant =
        insert(:oauth_grant, client_name: "other user grant", user: other_user, team: team)

      conn = get(conn, ~p"/settings/connected-apps")

      assert html = html_response(conn, 200)

      refute html =~ revoked_grant.client_name
      refute html =~ expired_grant.client_name
      refute html =~ other_user_grant.client_name

      assert table_rows(html) == [
               {[
                  [named_grant.client_name, "Client ID: #{named_grant.client_id}"],
                  "My personal sites",
                  TextHelpers.format_date(yesterday),
                  "5 hours ago",
                  # delete cell has no text
                  ""
                ], ~p"/settings/connected-apps/#{named_grant.id}"},
               {[
                  named_grant.client_id,
                  "My personal sites",
                  TextHelpers.format_date(now),
                  "Never",
                  ""
                ], ~p"/settings/connected-apps/#{unnamed_grant.id}"}
             ]
    end
  end

  # Each row's cells and the path its revoke button deletes. A cell with
  # several lines (spans) is a list of their texts.
  defp table_rows(html) do
    html
    |> find("tbody tr")
    |> Enum.map(fn row ->
      delete_link_url = text_of_attr(row, "a[data-method=delete]", "data-to")
      cells = row |> find("td") |> Enum.map(&cell_contents/1)
      {cells, delete_link_url}
    end)
  end

  defp cell_contents(cell) do
    spans = cell |> find("span") |> Enum.to_list()

    if length(spans) > 1 do
      Enum.map(spans, &text/1)
    else
      text(cell)
    end
  end
end
