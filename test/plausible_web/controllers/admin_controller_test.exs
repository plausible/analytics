defmodule PlausibleWeb.AdminControllerTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Teams.Test

  alias Plausible.Repo
  alias Plausible.Teams

  describe "GET /crm/teams/team/:team_id/usage" do
    setup [:create_user, :log_in, :create_team]

    @tag :ee_only
    test "returns 403 if the logged in user is not a super admin", %{conn: conn} do
      conn = get(conn, "/crm/teams/team/1/usage")
      assert response(conn, 403) == "Not allowed"
    end

    @tag :ee_only
    test "returns usage data as a standalone page", %{conn: conn, user: user, team: team} do
      patch_env(:super_admin_user_ids, [user.id])
      conn = get(conn, "/crm/teams/team/#{team.id}/usage")
      assert response(conn, 200) =~ "<html"
    end

    @tag :ee_only
    test "returns usage data in embeddable form when requested", %{
      conn: conn,
      user: user,
      team: team
    } do
      patch_env(:super_admin_user_ids, [user.id])
      conn = get(conn, "/crm/teams/team/#{team.id}/usage?embed=true")
      refute response(conn, 200) =~ "<html"
    end
  end

  describe "GET /crm/sites/site" do
    setup [:create_user, :log_in]

    @tag :ee_only
    test "pagination works correctly when multiple memberships per site present", %{
      conn: conn,
      user: user
    } do
      patch_env(:super_admin_user_ids, [user.id])

      s1 = new_site(inserted_at: ~N[2024-01-01 00:00:00])
      for _ <- 1..3, do: add_guest(s1, role: :viewer)
      s2 = new_site(inserted_at: ~N[2024-01-02 00:00:00])
      for _ <- 1..3, do: add_guest(s2, role: :viewer)
      s3 = new_site(inserted_at: ~N[2024-01-03 00:00:00])
      for _ <- 1..3, do: add_guest(s3, role: :viewer)

      conn1 = get(conn, "/crm/sites/site", %{"limit" => "2"})
      page1_html = html_response(conn1, 200)

      assert page1_html =~ s3.domain
      assert page1_html =~ s2.domain
      refute page1_html =~ s1.domain

      conn2 = get(conn, "/crm/sites/site", %{"page" => "2", "limit" => "2"})
      page2_html = html_response(conn2, 200)

      refute page2_html =~ s3.domain
      refute page2_html =~ s2.domain
      assert page2_html =~ s1.domain
    end
  end

  describe "DELETE /crm/auth/user/:user_id" do
    setup [:create_user, :log_in]

    setup %{user: user} do
      patch_env(:super_admin_user_ids, [user.id])

      :ok
    end

    @tag :ee_only
    test "deletes a user without a team", %{conn: conn} do
      another_user = new_user()

      conn = delete(conn, "/crm/auth/user/#{another_user.id}")
      assert redirected_to(conn, 302) == "/crm/auth/user"

      refute Repo.reload(another_user)
    end

    @tag :ee_only
    test "deletes a user with a personal team without subscription", %{conn: conn} do
      another_user = new_user()
      site = new_site(owner: another_user)
      team = team_of(another_user)

      conn = delete(conn, "/crm/auth/user/#{another_user.id}")
      assert redirected_to(conn, 302) == "/crm/auth/user"

      refute Repo.reload(another_user)
      refute Repo.reload(site)
      refute Repo.reload(team)
    end

    @tag :ee_only
    test "fails to delete a user with a personal team with active subscription", %{conn: conn} do
      another_user = new_user() |> subscribe_to_growth_plan()
      site = new_site(owner: another_user)
      team = team_of(another_user)

      conn = delete(conn, "/crm/auth/user/#{another_user.id}")
      assert redirected_to(conn, 302) == "/crm/auth/user/#{another_user.id}"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "User's personal team has an active subscription"

      assert Repo.reload(another_user)
      assert Repo.reload(site)
      assert Repo.reload(team)
    end

    @tag :ee_only
    test "fails to delete a user who is the only owner on a public team", %{conn: conn} do
      another_user = new_user()
      site = new_site(owner: another_user)
      team = another_user |> team_of() |> Plausible.Teams.complete_setup()

      conn = delete(conn, "/crm/auth/user/#{another_user.id}")
      assert redirected_to(conn, 302) == "/crm/auth/user/#{another_user.id}"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "The user is the only public team owner"

      assert Repo.reload(another_user)
      assert Repo.reload(site)
      assert Repo.reload(team)
    end
  end

  describe "DELETE /crm/teams/team/:team_id" do
    setup [:create_user, :log_in]

    setup %{user: user} do
      patch_env(:super_admin_user_ids, [user.id])

      :ok
    end

    @tag :ee_only
    test "deletes a team", %{conn: conn} do
      another_user = new_user()
      site = new_site(owner: another_user)
      team = team_of(another_user)

      conn = delete(conn, "/crm/teams/team/#{team.id}")
      assert redirected_to(conn, 302) == "/crm/teams/team"

      refute Repo.reload(team)
      refute Repo.reload(site)
      assert Repo.reload(another_user)
    end

    @tag :ee_only
    test "fails to delete a team with an active subscription", %{conn: conn} do
      another_user = new_user() |> subscribe_to_growth_plan()
      site = new_site(owner: another_user)
      team = team_of(another_user)

      conn = delete(conn, "/crm/teams/team/#{team.id}")
      assert redirected_to(conn, 302) == "/crm/teams/team/#{team.id}"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "The team has an active subscription"

      assert Repo.reload(team)
      assert Repo.reload(site)
      assert Repo.reload(another_user)
    end
  end

  describe "POST /crm/sites/site/:site_id" do
    setup [:create_user, :log_in]

    @tag :ee_only
    test "resets stats start date on native stats start time change", %{conn: conn, user: user} do
      patch_env(:super_admin_user_ids, [user.id])

      site =
        new_site(
          public: false,
          stats_start_date: ~D[2022-03-14],
          native_stats_start_at: ~N[2024-01-22 14:28:00]
        )

      params = %{
        "site" => %{
          "domain" => site.domain,
          "timezone" => site.timezone,
          "public" => "false",
          "native_stats_start_at" => "2024-02-12 12:00:00",
          "ingest_rate_limit_scale_seconds" => site.ingest_rate_limit_scale_seconds,
          "ingest_rate_limit_threshold" => site.ingest_rate_limit_threshold
        }
      }

      conn = put(conn, "/crm/sites/site/#{site.id}", params)
      assert redirected_to(conn, 302) == "/crm/sites/site"

      site = Repo.reload!(site)

      refute site.public
      assert site.native_stats_start_at == ~N[2024-02-12 12:00:00]
      assert site.stats_start_date == nil
    end
  end

  describe "GET /crm/billing/user/:user_id/current_plan" do
    setup [:create_user, :log_in]

    @tag :ee_only
    test "returns 403 if the logged in user is not a super admin", %{conn: conn} do
      conn = get(conn, "/crm/billing/team/0/current_plan")
      assert response(conn, 403) == "Not allowed"
    end

    @tag :ee_only
    test "returns empty state for non-existent team", %{conn: conn, user: user} do
      patch_env(:super_admin_user_ids, [user.id])

      conn = get(conn, "/crm/billing/team/0/current_plan")
      assert json_response(conn, 200) == %{"features" => []}
    end

    @tag :ee_only
    test "returns empty state for user without subscription", %{conn: conn, user: user} do
      patch_env(:super_admin_user_ids, [user.id])
      _site = new_site(owner: user)
      team = team_of(user)

      conn = get(conn, "/crm/billing/team/#{team.id}/current_plan")
      assert json_response(conn, 200) == %{"features" => []}
    end

    @tag :ee_only
    test "returns empty state for user with subscription with non-existent paddle plan ID", %{
      conn: conn,
      user: user
    } do
      patch_env(:super_admin_user_ids, [user.id])

      subscribe_to_plan(user, "does-not-exist")

      team = team_of(user)

      conn = get(conn, "/crm/billing/team/#{team.id}/current_plan")
      assert json_response(conn, 200) == %{"features" => []}
    end

    @tag :ee_only
    test "returns plan data for user with subscription", %{conn: conn, user: user} do
      patch_env(:super_admin_user_ids, [user.id])

      subscribe_to_plan(user, "857104")
      team = team_of(user)

      conn = get(conn, "/crm/billing/team/#{team.id}/current_plan")

      assert json_response(conn, 200) == %{
               "features" => ["goals", "shared_links"],
               "monthly_pageview_limit" => 10_000_000,
               "site_limit" => 10,
               "team_member_limit" => 3
             }
    end
  end

  describe "POST /crm/auth/api_key" do
    setup [:create_user, :log_in]

    @tag :kaffy_quirks
    test "creates a team-bound API key", %{conn: conn, user: user} do
      patch_env(:super_admin_user_ids, [user.id])

      another_user = new_user()
      team = another_user |> subscribe_to_business_plan() |> team_of()

      params = %{
        "api_key" => %{
          "name" => "Some key",
          "key" => Ecto.UUID.generate(),
          "scope" => "stats:read:*",
          "user_id" => "#{another_user.id}"
        }
      }

      conn = post(conn, "/crm/auth/api_key", params)

      assert api_key = Repo.get_by(Plausible.Auth.ApiKey, user_id: another_user.id)

      assert redirected_to(conn, 302) == "/crm/auth/api_key"

      assert api_key.team_id == team.id
      assert api_key.user_id == another_user.id
    end

    @tag :kaffy_quirks
    test "Creates personal team when creating the api key if there's none", %{
      conn: conn,
      user: user
    } do
      patch_env(:super_admin_user_ids, [user.id])

      another_user = new_user()

      another_team = new_site().team |> Teams.complete_setup()
      add_member(another_team, user: another_user, role: :owner)

      params = %{
        "api_key" => %{
          "name" => "Some key",
          "key" => Ecto.UUID.generate(),
          "scopes" => Jason.encode!(["stats:read:*"]),
          "user_id" => "#{another_user.id}"
        }
      }

      conn = post(conn, "/crm/auth/api_key", params)

      assert api_key = Repo.get_by(Plausible.Auth.ApiKey, user_id: another_user.id)

      assert {:ok, personal_team} = Teams.get_owned_team(another_user, only_not_setup?: true)

      assert redirected_to(conn, 302) == "/crm/auth/api_key"

      assert api_key.team_id == personal_team.id
    end

    @tag :kaffy_quirks
    test "Creates team for a particular team if provided", %{conn: conn, user: user} do
      patch_env(:super_admin_user_ids, [user.id])

      another_user = new_user() |> subscribe_to_business_plan()

      another_team = new_site().team |> Teams.complete_setup()
      add_member(another_team, user: another_user, role: :owner)

      params = %{
        "api_key" => %{
          "team_identifier" => another_team.identifier,
          "name" => "Some key",
          "key" => Ecto.UUID.generate(),
          "scopes" => Jason.encode!(["stats:read:*"]),
          "user_id" => "#{another_user.id}"
        }
      }

      conn = post(conn, "/crm/auth/api_key", params)

      assert api_key = Repo.get_by(Plausible.Auth.ApiKey, user_id: another_user.id)

      assert redirected_to(conn, 302) == "/crm/auth/api_key"

      assert api_key.team_id == another_team.id
    end
  end

  describe "PUT /crm/auth/api_key/:id" do
    setup [:create_user, :log_in]

    @tag :ee_only
    test "updates an API key", %{conn: conn, user: user} do
      patch_env(:super_admin_user_ids, [user.id])

      another_user = new_user()
      team = another_user |> subscribe_to_business_plan() |> team_of()

      api_key = insert(:api_key, user: user, team: team)

      assert api_key.scopes == ["stats:read:*"]

      params = %{
        "api_key" => %{
          "name" => "Some key",
          "key" => Ecto.UUID.generate(),
          "scopes" => Jason.encode!(["sites:provision:*"]),
          "user_id" => "#{another_user.id}"
        }
      }

      conn = put(conn, "/crm/auth/api_key/#{api_key.id}", params)

      assert api_key = Repo.get_by(Plausible.Auth.ApiKey, user_id: another_user.id)

      assert redirected_to(conn, 302) == "/crm/auth/api_key"

      assert api_key.team_id == team.id
      assert api_key.scopes == ["sites:provision:*"]
    end

    @tag :ee_only
    test "leaves legacy API key without a team on update", %{conn: conn, user: user} do
      patch_env(:super_admin_user_ids, [user.id])

      another_user = new_user()
      _team = another_user |> subscribe_to_business_plan() |> team_of()

      api_key = insert(:api_key, user: user)

      assert api_key.scopes == ["stats:read:*"]

      params = %{
        "api_key" => %{
          "name" => "Some key",
          "key" => Ecto.UUID.generate(),
          "scopes" => Jason.encode!(["sites:provision:*"]),
          "user_id" => "#{another_user.id}"
        }
      }

      conn = put(conn, "/crm/auth/api_key/#{api_key.id}", params)

      assert api_key = Repo.get_by(Plausible.Auth.ApiKey, user_id: another_user.id)

      assert redirected_to(conn, 302) == "/crm/auth/api_key"

      refute api_key.team_id
      assert api_key.scopes == ["sites:provision:*"]
    end
  end
end
