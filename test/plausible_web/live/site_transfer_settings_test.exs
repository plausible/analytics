defmodule PlausibleWeb.Live.SiteTransferSettingsTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Repo
  use Bamboo.Test, shared: true

  import Phoenix.LiveViewTest

  @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

  setup [:create_user, :log_in, :create_site]

  describe "mount" do
    test "renders the Team radio as disabled when user has no other team", %{
      conn: conn,
      site: site
    } do
      {:ok, _lv, html} = get_liveview(conn, site)

      assert html =~ "Transfer site"
      assert html =~ "Move this site to another team or Plausible account"
      assert html =~ "Another Plausible account"

      assert element_exists?(html, ~s|input[name="form[destination]"][value="account"]|)

      assert element_exists?(
               html,
               ~s|input[name="form[destination]"][value="team"][disabled]|
             )

      assert text_of_element(html, "#site-transfer-form") =~
               "You aren't a member of any other teams"

      assert element_exists?(
               html,
               ~s|input[name="form[destination]"][value="my_team"][disabled]|
             )

      assert text_of_element(html, "#site-transfer-form") =~
               "The site is already in your personal sites"
    end

    test "renders team destinations enabled when the user has another team", %{
      conn: conn,
      user: user,
      site: site
    } do
      _team2 = join_2nd_team(user)

      {:ok, _lv, html} = get_liveview(conn, site)

      assert element_exists?(html, ~s|input[name="form[destination]"][value="team"]|)
      assert element_exists?(html, ~s|input[name="form[destination]"][value="account"]|)

      refute element_exists?(
               html,
               ~s|input[name="form[destination]"][value="team"][disabled]|
             )

      assert element_exists?(
               html,
               ~s|input[name="form[destination]"][value="my_team"][disabled]|
             )

      assert html =~ "The site will immediately move to the selected team"
      refute html =~ "joe@example.com"

      refute text_of_element(html, "#site-transfer-form") =~
               "You aren't a member of any other teams"
    end

    test "renders personal team destination enabled when the user transfers from another team", %{
      conn: conn,
      user: user
    } do
      _team2 = join_2nd_team(user)

      owner = new_user()
      site = new_site(owner: owner)
      add_member(site.team, user: user, role: :admin)

      {:ok, _lv, html} = get_liveview(conn, site)

      assert element_exists?(html, ~s|input[name="form[destination]"][value="team"]|)
      assert element_exists?(html, ~s|input[name="form[destination]"][value="account"]|)
      assert element_exists?(html, ~s|input[name="form[destination]"][value="my_team"]|)

      refute element_exists?(
               html,
               ~s|input[name="form[destination]"][value="team"][disabled]|
             )

      refute element_exists?(
               html,
               ~s|input[name="form[destination]"][value="my_team"][disabled]|
             )

      assert html =~ "The site will immediately move to the selected team"
      refute html =~ "example@email.com"

      refute text_of_element(html, "#site-transfer-form") =~
               "You aren't a member of any other teams"

      refute text_of_element(html, "#site-transfer-form") =~
               "The site is already in your personal sites"
    end

    test "renders personal team destination disabled if user does not have one", %{
      conn: conn,
      user: user,
      site: site
    } do
      _team2 = join_2nd_team(user)

      Repo.delete!(site.team)

      owner = new_user()
      site = new_site(owner: owner)
      add_member(site.team, user: user, role: :admin)

      {:ok, _lv, html} = get_liveview(conn, site)

      assert element_exists?(html, ~s|input[name="form[destination]"][value="team"]|)
      assert element_exists?(html, ~s|input[name="form[destination]"][value="account"]|)
      assert element_exists?(html, ~s|input[name="form[destination]"][value="my_team"]|)

      refute element_exists?(
               html,
               ~s|input[name="form[destination]"][value="team"][disabled]|
             )

      assert element_exists?(
               html,
               ~s|input[name="form[destination]"][value="my_team"][disabled]|
             )

      assert text_of_element(html, "#site-transfer-form") =~
               "You don't have an active subscription"
    end

    test "Team destination is preselected when available", %{
      conn: conn,
      user: user,
      site: site
    } do
      _team2 = join_2nd_team(user)

      {:ok, _lv, html} = get_liveview(conn, site)

      assert element_exists?(
               html,
               ~s|input[name="form[destination]"][value="team"][checked]|
             )

      refute element_exists?(
               html,
               ~s|input[name="form[destination]"][value="account"][checked]|
             )

      refute element_exists?(
               html,
               ~s|input[name="form[destination]"][value="my_team"][checked]|
             )
    end

    test "Personal team destination is preselected if available and team destination is unavailable",
         %{
           conn: conn,
           user: user
         } do
      owner = new_user()
      site = new_site(owner: owner)
      add_member(site.team, user: user, role: :admin)

      {:ok, _lv, html} = get_liveview(conn, site)

      refute element_exists?(
               html,
               ~s|input[name="form[destination]"][value="team"][checked]|
             )

      refute element_exists?(
               html,
               ~s|input[name="form[destination]"][value="account"][checked]|
             )

      assert element_exists?(
               html,
               ~s|input[name="form[destination]"][value="my_team"][checked]|
             )
    end
  end

  describe "switching destination" do
    test "changing to Account hides team picker and shows email input", %{
      conn: conn,
      user: user,
      site: site
    } do
      _team2 = join_2nd_team(user)

      {:ok, lv, _html} = get_liveview(conn, site)

      html =
        lv
        |> element("#site-transfer-form")
        |> render_change(%{"form" => %{"destination" => "account"}})

      assert html =~ "Email address"
      assert html =~ "example@email.com"
      refute html =~ "The site will immediately move to the selected team"

      assert text_of_attr(html, ~s|button[type=submit]|, "phx-disable-with") ==
               "Transferring..."

      assert text_of_element(html, ~s|button[type=submit]|) =~ "Send transfer request"
    end

    test "changing to Team hides email and shows team picker", %{
      conn: conn,
      user: user,
      site: site
    } do
      _team2 = join_2nd_team(user)

      {:ok, lv, _html} = get_liveview(conn, site)

      lv
      |> element("#site-transfer-form")
      |> render_change(%{"form" => %{"destination" => "account"}})

      html =
        lv
        |> element("#site-transfer-form")
        |> render_change(%{"form" => %{"destination" => "team"}})

      assert html =~ "Select a team"
      refute html =~ "Email address"
      assert text_of_element(html, ~s|button[type=submit]|) =~ "Move site"
    end

    test "changing to My personal sites hides everything else", %{
      conn: conn,
      user: user
    } do
      _team2 = join_2nd_team(user)

      site = new_site()
      add_member(site.team, user: user, role: :admin)

      {:ok, lv, _html} = get_liveview(conn, site)

      lv
      |> element("#site-transfer-form")
      |> render_change(%{"form" => %{"destination" => "account"}})

      html =
        lv
        |> element("#site-transfer-form")
        |> render_change(%{"form" => %{"destination" => "my_team"}})

      refute html =~ "Select a team"
      refute html =~ "Email address"

      assert text_of_element(html, ~s|button[type=submit]|) =~ "Move site"
    end
  end

  describe "submitting (account destination)" do
    test "creates a site transfer and redirects to settings/people", %{
      conn: conn,
      site: site
    } do
      {:ok, lv, _html} = get_liveview(conn, site)

      lv
      |> element("#site-transfer-form")
      |> render_submit(%{
        "form" => %{"destination" => "account", "email" => "john.doe@example.com"}
      })

      assert_redirect(lv, "/#{URI.encode_www_form(site.domain)}/settings/people")

      assert_email_delivered_with(
        to: [nil: "john.doe@example.com"],
        subject: @subject_prefix <> "Request to transfer ownership of #{site.domain}"
      )
    end

    test "renders an inline error when the user has already been invited", %{
      conn: conn,
      user: user,
      site: site
    } do
      invited = "john.doe@example.com"

      {:ok, _invitation} =
        Plausible.Teams.Invitations.InviteToSite.invite(site, user, invited, :editor)

      {:ok, lv, _html} = get_liveview(conn, site)

      html =
        lv
        |> element("#site-transfer-form")
        |> render_submit(%{
          "form" => %{"destination" => "account", "email" => invited}
        })

      assert html =~ "Invitation has already been sent"
    end

    test "validates that an email is required", %{conn: conn, site: site} do
      {:ok, lv, _html} = get_liveview(conn, site)

      html =
        lv
        |> element("#site-transfer-form")
        |> render_submit(%{"form" => %{"destination" => "account", "email" => ""}})

      assert html =~ "Please enter an email address"
    end
  end

  describe "submitting (team destination)" do
    test "successfully changes the site's team and redirects to sites listing", %{
      conn: conn,
      user: user,
      site: site
    } do
      team2 = join_2nd_team(user, subscribe?: true)

      {:ok, lv, _html} = get_liveview(conn, site)

      lv
      |> element("#site-transfer-form")
      |> render_submit(%{
        "form" => %{"destination" => "team", "team_identifier" => team2.identifier}
      })

      assert_redirect(lv, "/sites?__team=#{team2.identifier}")

      assert Plausible.Repo.reload!(site).team_id == team2.id
    end

    @tag :ee_only
    test "renders an inline error when the destination team has no subscription", %{
      conn: conn,
      user: user,
      site: site
    } do
      team2 = join_2nd_team(user)

      {:ok, lv, _html} = get_liveview(conn, site)

      html =
        lv
        |> element("#site-transfer-form")
        |> render_submit(%{
          "form" => %{"destination" => "team", "team_identifier" => team2.identifier}
        })

      assert text_of_element(html, "#site-transfer-form") =~
               "This team doesn't have a subscription"
    end

    @tag :ee_only
    test "renders an inline error when usage exceeds destination team's limits", %{
      conn: conn,
      user: user,
      site: site
    } do
      team2 = join_2nd_team(user, subscribe?: true)

      generate_usage_for(site, 11_000, NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -5))
      generate_usage_for(site, 11_000, NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -35))

      {:ok, lv, _html} = get_liveview(conn, site)

      html =
        lv
        |> element("#site-transfer-form")
        |> render_submit(%{
          "form" => %{"destination" => "team", "team_identifier" => team2.identifier}
        })

      assert text_of_element(html, "#site-transfer-form") =~
               "This site's usage exceeds the destination team's subscription limits"
    end

    test "validates that a team must be selected", %{conn: conn, user: user, site: site} do
      _team2 = join_2nd_team(user)

      {:ok, lv, _html} = get_liveview(conn, site)

      html =
        lv
        |> element("#site-transfer-form")
        |> render_submit(%{
          "form" => %{"destination" => "team", "team_identifier" => ""}
        })

      assert html =~ "Please select a team"
    end

    test "rejects an unknown team identifier", %{conn: conn, user: user, site: site} do
      _team2 = join_2nd_team(user)

      {:ok, lv, _html} = get_liveview(conn, site)

      html =
        lv
        |> element("#site-transfer-form")
        |> render_submit(%{
          "form" => %{
            "destination" => "team",
            "team_identifier" => Ecto.UUID.generate()
          }
        })

      assert html =~ "Please select a team"
    end

    test "rejects a team identifier the user has no transfer permissions for", %{
      conn: conn,
      user: user,
      site: site
    } do
      _team2 = join_2nd_team(user)
      team3 = join_2nd_team(user, role: :viewer)

      {:ok, lv, _html} = get_liveview(conn, site)

      html =
        lv
        |> element("#site-transfer-form")
        |> render_submit(%{
          "form" => %{
            "destination" => "team",
            "team_identifier" => team3.identifier
          }
        })

      assert html =~ "Please select a team"
    end
  end

  describe "submitting (my_team destination)" do
    test "successfully changes the site's team to personal team and redirects to sites listing",
         %{
           conn: conn,
           user: user
         } do
      owner = new_user()
      site = new_site(owner: owner)
      add_member(site.team, user: user, role: :admin)

      subscribe_to_growth_plan(user)
      my_team = team_of(user)

      {:ok, lv, _html} = get_liveview(conn, site)

      lv
      |> element("#site-transfer-form")
      |> render_submit(%{
        "form" => %{"destination" => "my_team", "my_team_available" => "true"}
      })

      assert_redirect(lv, "/sites?__team=#{my_team.identifier}")

      assert Plausible.Repo.reload!(site).team_id == my_team.id
    end

    @tag :ee_only
    test "renders an inline error when personal team has no subscription", %{
      conn: conn,
      user: user
    } do
      owner = new_user()
      site = new_site(owner: owner)
      add_member(site.team, user: user, role: :admin)

      {:ok, lv, _html} = get_liveview(conn, site)

      html =
        lv
        |> element("#site-transfer-form")
        |> render_submit(%{
          "form" => %{"destination" => "my_team", "my_team_available" => "true"}
        })

      assert text_of_element(html, "#site-transfer-form") =~ "You don't have a subscription"
    end

    @tag :ee_only
    test "renders an inline error when usage exceeds destination personal team's limits", %{
      conn: conn,
      user: user
    } do
      owner = new_user()
      site = new_site(owner: owner)
      add_member(site.team, user: user, role: :admin)

      subscribe_to_growth_plan(user)

      generate_usage_for(site, 11_000, NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -5))
      generate_usage_for(site, 11_000, NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -35))

      {:ok, lv, _html} = get_liveview(conn, site)

      html =
        lv
        |> element("#site-transfer-form")
        |> render_submit(%{
          "form" => %{"destination" => "my_team", "my_team_available" => "true"}
        })

      assert text_of_element(html, "#site-transfer-form") =~
               "This site's usage exceeds your subscription limits"
    end
  end

  defp get_liveview(conn, site) do
    conn = assign(conn, :live_module, PlausibleWeb.Live.SiteTransferSettings)
    live(conn, "/#{URI.encode_www_form(site.domain)}/settings/danger-zone")
  end

  defp join_2nd_team(user, opts \\ []) do
    role = Keyword.get(opts, :role, :admin)
    another = new_user()

    if opts[:subscribe?] do
      subscribe_to_growth_plan(another)
    end

    new_site(owner: another)
    team2 = another |> team_of() |> Plausible.Teams.complete_setup()
    add_member(team2, user: user, role: role)

    team2
  end
end
