defmodule PlausibleWeb.Live.CustomerSupport.UsersTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Teams.Test
  use Plausible
  @moduletag :ee_only

  on_ee do
    import Phoenix.LiveViewTest
    import Plausible.Test.Support.HTML

    defp open_user(id, qs \\ []) do
      Routes.customer_support_user_path(PlausibleWeb.Endpoint, :show, id, qs)
    end

    describe "overview" do
      setup [:create_user, :log_in, :create_site]

      setup %{user: user} do
        patch_env(:super_admin_user_ids, [user.id])
      end

      test "renders", %{conn: conn, user: user} do
        {:ok, _lv, html} = live(conn, open_user(user.id))
        text = text(html)
        assert text =~ user.name
        assert text =~ user.email

        assert [uid] = find(html, "#user-identifier")
        assert text_of_attr(uid, "value") == "#{user.id}"

        team = team_of(user)

        assert [_] =
                 find(
                   html,
                   ~s|a[href="#{Routes.customer_support_team_path(PlausibleWeb.Endpoint, :show, team.id)}"]|
                 )
      end

      test "404", %{conn: conn} do
        assert_raise Ecto.NoResultsError, fn ->
          {:ok, _lv, _html} = live(conn, open_user(9999))
        end
      end

      test "delete user", %{conn: conn, user: user} do
        {:ok, lv, _html} = live(conn, open_user(user.id))

        lv
        |> element(~s|button[phx-click="delete-user"]|)
        |> render_click()

        assert_redirect(lv, Routes.customer_support_path(PlausibleWeb.Endpoint, :index))

        refute Plausible.Repo.get(Plausible.Auth.User, user.id)
      end

      test "delete user with active subscription", %{conn: conn, user: user} do
        user |> subscribe_to_growth_plan()

        {:ok, lv, _html} = live(conn, open_user(user.id))

        lv
        |> element(~s|button[phx-click="delete-user"]|)
        |> render_click()

        text = lv |> render() |> text()

        assert text =~ "Cannot delete user with active subscription"

        assert Plausible.Repo.get(Plausible.Auth.User, user.id)
      end

      test "delete user when they're sole team owner", %{conn: conn, user: user} do
        site = new_site(owner: user)
        Plausible.Teams.complete_setup(site.team)

        {:ok, lv, _html} = live(conn, open_user(user.id))

        lv
        |> element(~s|button[phx-click="delete-user"]|)
        |> render_click()

        text = lv |> render() |> text()

        assert text =~ "Failed to delete user: :is_only_team_owner"

        assert Plausible.Repo.get(Plausible.Auth.User, user.id)
      end
    end

    describe "keys" do
      setup [:create_user, :log_in, :create_site]

      setup %{user: user} do
        patch_env(:super_admin_user_ids, [user.id])
      end

      test "renders", %{conn: conn, user: user} do
        k1 = insert(:api_key, user: user)
        k2 = insert(:api_key, user: user, team: team_of(user))
        k3 = insert(:api_key, user: new_user())

        {:ok, lv, html} = live(conn, open_user(user.id, tab: :keys))

        assert text(html) =~ "API Keys (2)"

        html = lv |> render() |> text()

        assert html =~ k1.key_prefix
        assert html =~ k2.key_prefix
        refute html =~ k3.key_prefix
      end
    end

    describe "2FA management" do
      setup [:create_user, :log_in, :create_site]

      setup %{user: user} do
        patch_env(:super_admin_user_ids, [user.id])
      end

      test "shows 2FA disabled status when user has no 2FA", %{conn: conn, user: user} do
        {:ok, _lv, html} = live(conn, open_user(user.id))

        assert text(html) =~ "Two-Factor Authentication: Disabled"
        refute text(html) =~ "Force Disable 2FA"
      end

      test "shows 2FA enabled status and disable button when user has 2FA", %{
        conn: conn,
        user: user
      } do
        {:ok, user, _} = Plausible.Auth.TOTP.initiate(user)
        {:ok, user, _} = Plausible.Auth.TOTP.enable(user, :skip_verify)

        {:ok, _lv, html} = live(conn, open_user(user.id))

        assert text(html) =~ "Two-Factor Authentication: Enabled"
        assert text(html) =~ "Force Disable 2FA"
      end

      test "force disables 2FA when button is clicked", %{conn: conn, user: user} do
        {:ok, user, _} = Plausible.Auth.TOTP.initiate(user)
        {:ok, user, _} = Plausible.Auth.TOTP.enable(user, :skip_verify)

        {:ok, lv, _html} = live(conn, open_user(user.id))

        lv |> element("[phx-click='force-disable-2fa']") |> render_click()

        html = render(lv)
        assert text(html) =~ "2FA has been force disabled"
        assert text(html) =~ "Two-Factor Authentication: Disabled"
        refute text(html) =~ "Force Disable 2FA"

        updated_user = Plausible.Repo.reload(user)
        refute Plausible.Auth.TOTP.enabled?(updated_user)
      end
    end
  end
end
