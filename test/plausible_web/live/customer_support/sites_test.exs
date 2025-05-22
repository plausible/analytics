defmodule PlausibleWeb.Live.CustomerSupport.SitesTest do
  use PlausibleWeb.ConnCase, async: false
  @moduletag :ee_only

  on_ee do
    use Plausible.Teams.Test
    use Plausible
    use Bamboo.Test, shared: true

    import Phoenix.LiveViewTest
    import Plausible.Test.Support.HTML

    defp open_site(id, opts \\ []) do
      Routes.customer_support_resource_path(
        PlausibleWeb.Endpoint,
        :details,
        :sites,
        :site,
        id,
        opts
      )
    end

    describe "overview" do
      setup [:create_user, :log_in, :create_site]

      setup %{user: user} do
        patch_env(:super_admin_user_ids, [user.id])
      end

      test "renders", %{conn: conn, site: site} do
        {:ok, _lv, html} = live(conn, open_site(site.id))
        assert text(html) =~ site.domain
      end

      test "404", %{conn: conn} do
        assert_raise Ecto.NoResultsError, fn ->
          {:ok, _lv, _html} = live(conn, open_site(9999))
        end
      end
    end

    describe "rescue zone" do
      setup [:create_user, :log_in, :create_site]

      setup %{user: user} do
        patch_env(:super_admin_user_ids, [user.id])
      end

      test "form renders", %{site: site, conn: conn} do
        {:ok, lv, _html} = live(conn, open_site(site.id, tab: "rescue-zone"))
        html = render(lv)

        form = ~s|form[phx-submit="init-transfer"]|

        assert element_exists?(html, ~s|#{form} input#inviter_email|)

        assert element_exists?(html, ~s|#{form} input#invitee_email|)

        assert element_exists?(html, ~s|#{form} input#submit-inviter_email|)

        assert element_exists?(html, ~s|#{form} input#submit-invitee_email|)

        assert element_exists?(html, ~s|#{form} button[type="submit"]|)
      end

      @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "
      test "form submission creates invitation", %{user: user, site: site, conn: conn} do
        {:ok, lv, _html} = live(conn, open_site(site.id, tab: "rescue-zone"))
        render(lv)

        type_into_combo(lv, "inviter_email", user.name)

        lv
        |> element("li#dropdown-inviter_email-option-1 a")
        |> render_click()

        type_into_combo(lv, "invitee_email", "arbitrary@example.com")

        lv
        |> element("li#dropdown-invitee_email-option-0 a")
        |> render_click()

        form = ~s|form[phx-submit="init-transfer"]|
        lv |> element(form) |> render_submit()

        assert_email_delivered_with(
          to: [nil: "arbitrary@example.com"],
          subject: @subject_prefix <> "Request to transfer ownership of #{site.domain}",
          html_body: ~r/#{user.email}/
        )
      end
    end

    defp type_into_combo(lv, id, text) do
      lv
      |> element("input##{id}")
      |> render_change(%{
        "_target" => ["display-#{id}"],
        "display-#{id}" => "#{text}"
      })
    end
  end
end
