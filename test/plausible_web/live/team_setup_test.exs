defmodule PlausibleWeb.Live.TeamSetupTest do
  use PlausibleWeb.ConnCase, async: false
  use Bamboo.Test, shared: true

  import Phoenix.LiveViewTest

  alias Plausible.Teams
  alias Plausible.Repo

  @url "/team/setup"
  @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

  describe "/team/setup" do
    setup [:create_user, :log_in]

    test "creates another team, without a choice, when the current team is set up", %{
      conn: conn,
      user: user
    } do
      {:ok, current_team} = Teams.create(user, "Current Team", [])

      {:ok, lv, html} = live(set_current_team(conn, current_team), @url)
      assert move_from_current_team_options(html) == []

      finish_setup(lv, name: "Another Team")

      assert [%{name: "Another Team"} = new_team, %{name: "Current Team"}] =
               Teams.Users.teams(user)

      assert_redirect(lv, "/settings/team/general?__team=" <> new_team.identifier)
    end

    test "renders a cancel link back to /sites", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @url)

      assert text_of_element(html, "#create-team-cancel") == "Cancel"
      assert text_of_attr(html, "#create-team-cancel", "href") == "/sites"
    end

    test "does not render the onboarding progress", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @url)

      refute element_exists?(html, "#flow-progress")
    end
  end

  describe "/team/setup?flow=register - after adding a site" do
    setup [:create_user, :log_in, :create_site]

    test "renders the team setup step of the onboarding progress", %{conn: conn, site: site} do
      {:ok, _lv, html} = live(conn, onboarding_url(site.domain))

      assert text_of_attr(html, ~s|#flow-progress [aria-current="step"]|, "aria-label") ==
               "Set up team"
    end

    test "does not offer a choice for the personal sites", %{conn: conn, site: site} do
      {:ok, _lv, html} = live(conn, onboarding_url(site.domain))

      assert move_from_current_team_options(html) == []
    end

    test "does not render the team switcher", %{conn: conn, site: site} do
      {:ok, _lv, html} = live(conn, onboarding_url(site.domain))

      refute html =~ "Create new team"
    end

    test "suggests a team name based on the site domain", %{conn: conn, user: user} do
      site = new_site(owner: user, domain: "shop.my-company.co.uk")

      {:ok, _lv, html} = live(conn, onboarding_url(site.domain))

      assert text_of_attr(html, ~s|input#create-team-form_name[name="team[name]"]|, "value") ==
               "My Company"
    end

    test "renders a skip link to the installation step", %{conn: conn, site: site} do
      {:ok, _lv, html} = live(conn, onboarding_url(site.domain))

      assert text_of_element(html, "#create-team-skip") == "Skip"

      assert text_of_attr(html, "#create-team-skip", "href") ==
               ~p"/#{site.domain}/installation?flow=register"
    end

    test "turns the personal team into a real team and continues to installation", %{
      conn: conn,
      site: site
    } do
      {:ok, lv, _html} = live(conn, onboarding_url(site.domain))

      finish_setup(lv, name: "Onboarded Team")

      assert_redirect(
        lv,
        ~p"/#{site.domain}/installation?flow=register&__team=#{site.team.identifier}"
      )

      team = Repo.reload!(site.team)
      assert team.setup_complete
      assert team.name == "Onboarded Team"
    end

    test "skips ahead to installation if the team is already set up", %{
      conn: conn,
      site: site
    } do
      team = Teams.complete_setup(site.team)
      conn = set_current_team(conn, team)
      expected_path = ~p"/#{site.domain}/installation?flow=register"

      assert {:error, {:redirect, %{to: ^expected_path}}} =
               live(conn, onboarding_url(site.domain))
    end

    test "ignores the domain of a site the user can't access", %{conn: conn} do
      other_site = new_site(domain: "other-company.com")

      {:ok, _lv, html} = live(conn, onboarding_url(other_site.domain))

      assert text_of_attr(html, "#create-team-skip", "href") == "/sites"

      assert text_of_attr(html, ~s|input#create-team-form_name[name="team[name]"]|, "value") ==
               "Jane Smith's team"
    end

    test "ignores the domain of a non-existent site when skipping ahead", %{
      conn: conn,
      site: site
    } do
      team = Teams.complete_setup(site.team)
      conn = set_current_team(conn, team)

      assert {:error, {:redirect, %{to: "/sites"}}} =
               live(conn, onboarding_url("evil.example.com"))
    end
  end

  describe "/team/setup?flow=register - after skipping adding a site" do
    setup [:create_user, :log_in]

    test "suggests a team name based on the user name", %{conn: conn} do
      {:ok, _lv, html} = live(conn, onboarding_url())

      assert text_of_attr(html, ~s|input#create-team-form_name[name="team[name]"]|, "value") ==
               "Jane Smith's team"
    end

    test "renders a skip link to /sites", %{conn: conn} do
      {:ok, _lv, html} = live(conn, onboarding_url())

      assert text_of_element(html, "#create-team-skip") == "Skip"
      assert text_of_attr(html, "#create-team-skip", "href") == "/sites"
    end

    test "creates a team from scratch and continues to /sites", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, onboarding_url())

      finish_setup(lv, name: "Onboarded Team")

      assert {:ok, team} = Teams.get_by_owner(user)
      assert team.setup_complete
      assert team.name == "Onboarded Team"

      assert_redirect(lv, "/sites?__team=" <> team.identifier)
    end

    @tag :ee_only
    test "shows an upgrade notice with a working skip link on a solo plan", %{
      conn: conn,
      user: user
    } do
      subscribe_to_starter_plan(user)

      {:ok, _lv, html} = live(conn, onboarding_url())

      assert text_of_element(html, "#team-setup-locked-notice") =~
               "Your plan doesn't include teams."

      assert text_of_attr(html, "#create-team-skip", "href") == "/sites"
      refute element_exists?(html, "#create-team-submit")
    end

    test "skips ahead to /sites if the team is already set up", %{conn: conn, user: user} do
      {:ok, team} = Teams.create(user, "Onboarded Team", [])
      conn = set_current_team(conn, team)

      assert {:error, {:redirect, %{to: "/sites"}}} = live(conn, onboarding_url())
    end
  end

  describe "/team/setup - from My Personal Sites" do
    setup [:create_user, :log_in]

    test "offers to move the personal sites, selected by default", %{conn: conn, user: user} do
      new_site(owner: user, domain: "first.example.com")
      new_site(owner: user, domain: "second.example.com")

      {:ok, _lv, html} = live(conn, @url)

      assert move_from_current_team_options(html) == ["true", "false"]
      assert selected_move_from_current_team(html) == ["true"]
      assert html =~ "first.example.com"
      assert html =~ "second.example.com"
    end

    test "lists up to 10 personal sites and counts the rest", %{conn: conn, user: user} do
      for n <- 1..12 do
        new_site(owner: user, domain: "site#{String.pad_leading("#{n}", 2, "0")}.example.com")
      end

      {:ok, _lv, html} = live(conn, @url)

      assert html =~ "site10.example.com"
      refute html =~ "site11.example.com"
      assert html =~ "and 2 more sites"
    end

    test "moving the personal sites turns them into the team", %{conn: conn, user: user} do
      site = new_site(owner: user)
      {:ok, lv, _html} = live(conn, @url)

      finish_setup(lv, name: "Moved Team")

      assert [%{name: "Moved Team", setup_complete: true} = team] = Teams.Users.teams(user)
      assert Enum.map(Teams.owned_sites(team), & &1.domain) == [site.domain]
    end

    test "starting with an empty team leaves the personal sites in place", %{
      conn: conn,
      user: user
    } do
      site = new_site(owner: user)
      {:ok, lv, _html} = live(conn, @url)

      select_move_from_current_team(lv, false)
      finish_setup(lv, name: "Empty Team")

      assert [
               %{name: "Empty Team", setup_complete: true} = new_team,
               %{name: "My personal sites", setup_complete: false} = personal_team
             ] = Teams.Users.teams(user)

      assert_redirect(lv, "/settings/team/general?__team=" <> new_team.identifier)
      assert Teams.owned_sites(new_team) == []
      assert Enum.map(Teams.owned_sites(personal_team), & &1.domain) == [site.domain]
    end

    test "does not offer to move someone else's personal sites", %{conn: conn, user: user} do
      other_site = new_site()
      add_guest(other_site, user: user, role: :viewer)

      {:ok, lv, html} = live(set_current_team(conn, other_site.team), @url)
      assert move_from_current_team_options(html) == []

      finish_setup(lv, name: "Own Team")

      assert [%{name: "Own Team", setup_complete: true}] = Teams.Users.teams(user)
      refute Teams.setup?(Teams.get(other_site.team.id))
    end
  end

  describe "/team/setup - without any existing team" do
    setup [:create_user, :log_in]

    test "renders the form with a suggested name", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @url)

      assert text_of_attr(html, ~s|input#create-team-form_name[name="team[name]"]|, "value") ==
               "Jane Smith's team"

      assert element_exists?(html, "#create-team-submit")
      refute element_exists?(html, "#feature-gate-overlay")
    end

    test "creates a new team from scratch and invites members", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, @url)

      finish_setup(lv,
        name: "Brand New Team",
        rows: %{"1" => %{"email" => "new@example.com", "role" => "editor"}}
      )

      assert {:ok, team} = Teams.get_by_owner(user)
      assert team.name == "Brand New Team"
      assert team.setup_complete

      assert_redirect(lv, "/settings/team/general?__team=" <> team.identifier)

      assert_email_delivered_with(
        to: [nil: "new@example.com"],
        subject: @subject_prefix <> "You've been invited to \"Brand New Team\" team"
      )

      assert [invitation] = Teams.Invitations.pending_team_invitations_for(team)
      assert invitation.email == "new@example.com"
      assert invitation.role == :editor
    end

    test "does not create a team when an invitation is rejected", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, @url)

      assert finish_setup(lv, rows: %{"1" => %{"email" => user.email, "role" => "viewer"}}) =~
               "You cannot invite yourself"

      assert {:error, :no_team} = Teams.get_by_owner(user)
    end

    @tag :ee_only
    test "defaults the member rows to the trial team member limit", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @url)

      assert elem_count(html, row_el()) == 10
    end
  end

  describe "/team/setup - suggested team name" do
    test "shortens a long user name to fit the limit", %{conn: conn} do
      user = new_user(name: String.duplicate("a", 55))
      {:ok, conn: conn} = log_in(%{user: user, conn: conn})
      {:ok, _team} = Teams.get_or_create(user)

      {:ok, _lv, html} = live(conn, @url)

      expected = String.duplicate("a", 43) <> "'s team"

      assert text_of_attr(html, ~s|input#create-team-form_name[name="team[name]"]|, "value") ==
               expected
    end

    test "falls back to a generic name when the user name carries a URL scheme", %{conn: conn} do
      user = new_user(name: "Cheap meds https://spam.example.com")
      {:ok, conn: conn} = log_in(%{user: user, conn: conn})
      {:ok, _team} = Teams.get_or_create(user)

      {:ok, _lv, html} = live(conn, @url)

      assert text_of_attr(html, ~s|input#create-team-form_name[name="team[name]"]|, "value") ==
               "My team"
    end

    test "falls back to a generic name when shortening overflows the column", %{conn: conn} do
      user = new_user(name: String.duplicate("👨‍👩‍👧‍👦", 36))
      {:ok, conn: conn} = log_in(%{user: user, conn: conn})
      {:ok, _team} = Teams.get_or_create(user)

      {:ok, _lv, html} = live(conn, @url)

      assert text_of_attr(html, ~s|input#create-team-form_name[name="team[name]"]|, "value") ==
               "My team"
    end
  end

  describe "/team/setup - team name" do
    setup [:create_user, :log_in, :create_team]

    test "suggests a default name without persisting it", %{conn: conn, team: team} do
      assert team.name == "My personal sites"
      {:ok, _lv, html} = live(conn, @url)

      assert text_of_attr(html, ~s|input#create-team-form_name[name="team[name]"]|, "value") ==
               "Jane Smith's team"

      assert Repo.reload!(team).name == "My personal sites"
    end

    test "renders form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @url)
      assert element_exists?(html, ~s|input#create-team-form_name[name="team[name]"]|)
      assert element_exists?(html, "#create-team-submit")
      assert elem_count(html, visible_row_el()) == 1
    end

    test "marks the name input as required so the browser blocks a blank submit", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @url)

      assert element_exists?(html, ~s|input#create-team-form_name[name="team[name]"][required]|)
    end

    test "rejects a blank name on submit", %{conn: conn, team: team} do
      {:ok, lv, _html} = live(conn, @url)

      assert finish_setup(lv, name: "") =~ "blank"
      refute Repo.reload!(team).setup_complete
    end

    test "setting team name containing a URL is rejected", %{conn: conn, team: team} do
      {:ok, lv, _html} = live(conn, @url)

      assert finish_setup(lv, name: "Cheap meds at https://spam.example.com") =~
               "cannot contain a URL"

      refute Repo.reload!(team).setup_complete
      assert Repo.reload!(team).name == "My personal sites"
    end

    test "setting team name longer than the limit is rejected", %{conn: conn, team: team} do
      {:ok, lv, _html} = live(conn, @url)

      assert finish_setup(lv, name: String.duplicate("a", 51)) =~
               "should be at most 50 character(s)"

      refute Repo.reload!(team).setup_complete
      assert Repo.reload!(team).name == "My personal sites"
    end

    test "rejects the reserved default team name on submit", %{conn: conn, team: team} do
      {:ok, lv, _html} = live(conn, @url)

      assert finish_setup(lv, name: "My personal sites") =~ "is reserved"
      refute Repo.reload!(team).setup_complete
      assert Repo.reload!(team).name == "My personal sites"
    end

    test "keeps a typed name when switching what happens to personal sites", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @url)

      lv
      |> element("#create-team-form")
      |> render_change(%{team: %{name: "Typed Name"}})

      html = select_move_from_current_team(lv, false)

      assert text_of_attr(html, ~s|input#create-team-form_name[name="team[name]"]|, "value") ==
               "Typed Name"
    end

    test "creating the team goes through once a valid name is submitted", %{
      conn: conn,
      team: team
    } do
      {:ok, lv, _html} = live(conn, @url)

      finish_setup(lv, name: "Fixed Team Name")

      assert_redirect(lv, "/settings/team/general?__team=" <> team.identifier)

      team = Repo.reload!(team)
      assert team.setup_complete
      assert team.name == "Fixed Team Name"
    end

    @tag :ee_only
    test "shows an upgrade notice instead of the form if the subscription team member limit is 0",
         %{conn: conn, user: user} do
      subscribe_to_starter_plan(user)

      {:ok, _lv, html} = live(conn, @url)

      assert text_of_element(html, "#team-setup-locked-notice") =~
               "Your plan doesn't include teams. To move your sites into a team, upgrade your subscription."

      assert element_exists?(html, "#create-team-cancel")
      refute element_exists?(html, "#create-team-submit")
      refute element_exists?(html, "#feature-gate-overlay")
    end

    @tag :ee_only
    test "allows starting with an empty team on a solo plan", %{conn: conn, user: user} do
      subscribe_to_starter_plan(user)
      {:ok, lv, _html} = live(conn, @url)

      select_move_from_current_team(lv, false)
      finish_setup(lv, name: "Empty Team")

      assert [%{name: "Empty Team", setup_complete: true}, %{name: "My personal sites"}] =
               Teams.Users.teams(user)
    end
  end

  # Adding/removing rows and picking a role all happen entirely client-side
  # (see assets/js/liveview/member-rows.js) - the server only ever sees the
  # final "rows" form data once, on submit. These tests exercise that submit
  # handling directly with the payload a real form submission would produce,
  # since ExUnit's LiveViewTest can't drive the client-side JS itself.
  describe "/team/setup - adding members" do
    setup [:create_user, :log_in, :create_team]

    test "starts out with a single empty row defaulting to viewer", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @url)
      assert elem_count(html, visible_row_el()) == 1

      assert text_of_attr(html, ~s|#{visible_row_el()} input[type="hidden"]|, "value") ==
               "viewer"
    end

    test "creating the team sends out an invitation for a filled row with the given role", %{
      conn: conn,
      team: team
    } do
      {:ok, lv, _html} = live(conn, @url)

      finish_setup(lv, rows: %{"1" => %{"email" => "new@example.com", "role" => "admin"}})

      assert_redirect(lv, "/settings/team/general?__team=" <> team.identifier)

      team = Repo.reload!(team)
      assert team.setup_complete

      assert_email_delivered_with(
        to: [nil: "new@example.com"],
        subject: @subject_prefix <> "You've been invited to \"#{team.name}\" team"
      )

      assert [invitation] = Teams.Invitations.pending_team_invitations_for(team)
      assert invitation.email == "new@example.com"
      assert invitation.role == :admin
    end

    test "blank rows are ignored on submit", %{conn: conn, team: team} do
      {:ok, lv, _html} = live(conn, @url)

      finish_setup(lv,
        rows: %{
          "1" => %{"email" => "", "role" => "viewer"},
          "2" => %{"email" => "second@example.com", "role" => "viewer"}
        }
      )

      assert_redirect(lv, "/settings/team/general?__team=" <> team.identifier)

      team = Repo.reload!(team)
      assert [invitation] = Teams.Invitations.pending_team_invitations_for(team)
      assert invitation.email == "second@example.com"
    end

    test "rejects invalid e-mails", %{conn: conn, team: team} do
      {:ok, lv, _html} = live(conn, @url)

      assert finish_setup(lv, rows: %{"1" => %{"email" => "not-an-email", "role" => "viewer"}}) =~
               "Make sure all e-mails are valid"

      refute Repo.reload!(team).setup_complete
      # the (valid) name submitted alongside the invalid row must not persist
      # on its own - team creation is all-or-nothing
      assert Repo.reload!(team).name == "My personal sites"
    end

    test "rejects duplicate e-mails across rows", %{conn: conn, team: team} do
      {:ok, lv, _html} = live(conn, @url)

      rows = %{
        "1" => %{"email" => "dup@example.com", "role" => "viewer"},
        "2" => %{"email" => "dup@example.com", "role" => "admin"}
      }

      assert finish_setup(lv, rows: rows) =~ "Make sure e-mails are unique"
      refute Repo.reload!(team).setup_complete
      assert Repo.reload!(team).name == "My personal sites"
    end

    test "rejects inviting yourself", %{conn: conn, team: team, user: user} do
      {:ok, lv, _html} = live(conn, @url)

      assert finish_setup(lv, rows: %{"1" => %{"email" => user.email, "role" => "admin"}}) =~
               "You cannot invite yourself"

      refute Repo.reload!(team).setup_complete
      assert Repo.reload!(team).name == "My personal sites"
    end

    test "rejects inviting a guest member", %{conn: conn, team: team} do
      site = new_site(team: team)
      guest = new_user()
      add_guest(site, role: :viewer, user: guest)

      {:ok, lv, _html} = live(conn, @url)

      assert finish_setup(lv, rows: %{"1" => %{"email" => guest.email, "role" => "admin"}}) =~
               "Some of these e-mails belong to site guests"

      refute Repo.reload!(team).setup_complete
      assert [] = Teams.Invitations.pending_team_invitations_for(team)
    end

    @tag :ee_only
    test "fails to create the team when the plan's member limit is breached", %{
      conn: conn,
      team: team
    } do
      insert(:growth_subscription, team: team)
      {:ok, lv, _html} = live(conn, @url)

      rows =
        for n <- 1..4, into: %{} do
          {to_string(n), %{"email" => "new#{n}@example.com", "role" => "viewer"}}
        end

      assert finish_setup(lv, rows: rows) =~ "Your account is limited to 3 team members"
      refute Repo.reload!(team).setup_complete
      # the transaction rolls back entirely, so the rename never lands either
      assert Repo.reload!(team).name == "My personal sites"
      assert_no_emails_delivered()
    end
  end

  # The client-side row cap itself (assets/js/liveview/member-rows.js) can't
  # be exercised here since ExUnit's LiveViewTest can't drive that JS - these
  # tests cover the server-computed limit instead, by counting how many rows
  # (visible or not) it renders up front for the JS to reveal on "add".
  describe "/team/setup - member row limit" do
    setup [:create_user, :log_in, :create_team]

    @tag :ee_only
    test "defaults to the trial team member limit", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @url)

      assert elem_count(html, row_el()) == 10
      refute html =~ "You can add more members in Team Settings later"
    end

    @tag :ee_only
    test "is not reduced by an existing guest member", %{conn: conn, team: team} do
      site = new_site(team: team)
      add_guest(site, role: :viewer, user: new_user())

      {:ok, _lv, html} = live(conn, @url)

      assert elem_count(html, row_el()) == 10
    end

    @tag :ee_only
    test "is capped at the trial limit for an unlimited plan", %{conn: conn, user: user} do
      subscribe_to_enterprise_plan(user, team_member_limit: :unlimited)

      {:ok, lv, html} = live(conn, @url)

      assert elem_count(html, row_el()) == 10
      assert html =~ "You can add more members in Team Settings later"

      html = select_move_from_current_team(lv, false)

      assert elem_count(html, row_el()) == 10
      refute html =~ "You can add more members in Team Settings later"
    end

    @tag :ee_only
    test "is capped at the plan limit when it is below the trial limit", %{
      conn: conn,
      team: team
    } do
      insert(:growth_subscription, team: team)

      {:ok, lv, html} = live(conn, @url)

      assert elem_count(html, row_el()) == 3
      refute html =~ "You can add more members in Team Settings later"

      html = select_move_from_current_team(lv, false)

      assert elem_count(html, row_el()) == 3
      assert html =~ "You can add more members in Team Settings later"
    end

    @tag :ee_only
    test "renders no rows for a solo team (member limit 0)", %{conn: conn, user: user} do
      subscribe_to_starter_plan(user)

      # Normally, starter tier accounts shouldn't even be setting up teams because
      # there's no point to do so. However, their access to the team setup page is
      # not restricted on the plug level, so this test makes sure it behaves
      # correctly and doesn't crash even in that scenario.
      {:ok, lv, _html} = live(conn, @url)
      html = select_move_from_current_team(lv, false)

      assert elem_count(html, row_el()) == 0
    end
  end

  defp onboarding_url(), do: @url <> "?flow=register"
  defp onboarding_url(domain), do: @url <> "?flow=register&domain=" <> domain

  defp row_el(), do: ~s|#member-rows > div|
  defp visible_row_el(), do: ~s|#member-rows > div:not(.hidden)|

  # In the browser, clicking a radio triggers both the form's phx-change and its own phx-click.
  defp select_move_from_current_team(lv, move?) do
    lv
    |> element("#create-team-form")
    |> render_change(%{move_from_current_team: "#{move?}"})

    lv
    |> element(~s|input[name="move_from_current_team"][value="#{move?}"]|)
    |> render_click()
  end

  defp move_from_current_team_options(html) do
    html
    |> find(~s|input[name="move_from_current_team"]|)
    |> LazyHTML.attribute("value")
  end

  defp selected_move_from_current_team(html) do
    html
    |> find(~s|input[name="move_from_current_team"][checked]|)
    |> LazyHTML.attribute("value")
  end

  defp finish_setup(lv, opts) do
    name = Keyword.get(opts, :name, "Jane Smith's team")
    rows = Keyword.get(opts, :rows, %{"1" => %{"email" => "", "role" => "viewer"}})

    lv
    |> element("#create-team-form")
    |> render_submit(%{"team" => %{"name" => name}, "rows" => rows})
  end
end
