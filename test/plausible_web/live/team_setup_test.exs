defmodule PlausibleWeb.Live.TeamSetupTest do
  use PlausibleWeb.ConnCase, async: false
  use Bamboo.Test, shared: true

  import Phoenix.LiveViewTest

  alias Plausible.Teams
  alias Plausible.Repo

  @url "/team/setup"
  @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

  describe "/team/setup - edge cases" do
    setup [:create_user, :log_in]

    test "redirects if there's no implicit team created", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/sites"}}} = live(conn, @url)
    end

    test "redirects to /team/general if team is already set up", %{conn: conn, user: user} do
      {:ok, team} = Teams.get_or_create(user)
      Teams.complete_setup(team)
      conn = set_current_team(conn, team)
      assert {:error, {:redirect, %{to: "/settings/team/general"}}} = live(conn, @url)
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
      assert elem_count(html, row_el()) == 1
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
    test "blurs UI with an upgrade CTA if the subscription team member limit is 0", %{
      conn: conn,
      user: user
    } do
      subscribe_to_starter_plan(user)

      {:ok, _lv, html} = live(conn, @url)

      assert element_exists?(html, "#feature-gate-inner-block-container")
      assert element_exists?(html, "#feature-gate-overlay")
      assert text_of_element(html, "#feature-gate-overlay") =~ "Upgrade to unlock"
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
      assert elem_count(html, row_el()) == 1
      assert text_of_attr(html, ~s|#member-rows input[type="hidden"]|, "value") == "viewer"
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
    end

    test "rejects duplicate e-mails across rows", %{conn: conn, team: team} do
      {:ok, lv, _html} = live(conn, @url)

      rows = %{
        "1" => %{"email" => "dup@example.com", "role" => "viewer"},
        "2" => %{"email" => "dup@example.com", "role" => "admin"}
      }

      assert finish_setup(lv, rows: rows) =~ "Make sure e-mails are unique"
      refute Repo.reload!(team).setup_complete
    end

    test "rejects inviting yourself", %{conn: conn, team: team, user: user} do
      {:ok, lv, _html} = live(conn, @url)

      assert finish_setup(lv, rows: %{"1" => %{"email" => user.email, "role" => "admin"}}) =~
               "You cannot invite yourself"

      refute Repo.reload!(team).setup_complete
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
      assert_no_emails_delivered()
    end
  end

  defp row_el(), do: ~s|#member-rows > div|

  defp finish_setup(lv, opts) do
    name = Keyword.get(opts, :name, "Jane Smith's team")
    rows = Keyword.get(opts, :rows, %{"1" => %{"email" => "", "role" => "viewer"}})

    lv
    |> element("#create-team-form")
    |> render_submit(%{"team" => %{"name" => name}, "rows" => rows})
  end
end
