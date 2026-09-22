defmodule PlausibleWeb.Live.CustomerSupport.EmailSuppressionsTest do
  use PlausibleWeb.ConnCase, async: false
  @moduletag :ee_only

  on_ee do
    import Phoenix.LiveViewTest

    alias Plausible.EmailSuppressions
    alias Plausible.Postmark
    alias Plausible.Repo

    defp open_suppressions(qs \\ []) do
      ~p"/cs/email-suppressions?#{qs}"
    end

    setup [:create_user, :log_in]

    setup %{user: user} do
      patch_env(:super_admin_user_ids, [user.id])
    end

    test "renders suppressions, most recently suppressed first", %{conn: conn} do
      {:ok, _} =
        EmailSuppressions.create_from_bounce(%{
          email: "hard@example.com",
          reason: :hard_bounce,
          source: :webhook,
          postmark_bounce_id: 12_345,
          postmark_inactive: true,
          can_activate: true,
          details: "Unknown user"
        })

      {:ok, _} =
        EmailSuppressions.create_from_spam_complaint(%{
          email: "complainer@example.com",
          source: :backfill
        })

      {:ok, _lv, html} = live(conn, open_suppressions())
      text = text(html)

      assert text =~ "E-mail suppressions"
      assert text =~ "hard@example.com"
      assert text =~ "complainer@example.com"
      assert text =~ "Hard bounce"
      assert text =~ "Spam complaint"

      hard_row = text_of_element(html, "tbody tr:last-child")
      assert hard_row =~ "Details"
      assert hard_row =~ "Bounce ID: 12345"
      assert hard_row =~ "Inactive"
      assert hard_row =~ "Can reactivate"

      assert html =~ "Unknown user"

      # most recently suppressed (complainer) listed first
      assert text_of_element(html, "tbody tr:first-child") =~ "complainer@example.com"
    end

    test "filters by reason", %{conn: conn} do
      {:ok, _} =
        EmailSuppressions.create_from_bounce(%{
          email: "hard@example.com",
          reason: :hard_bounce,
          source: :webhook
        })

      {:ok, _} =
        EmailSuppressions.create_from_bounce(%{
          email: "blocked@example.com",
          reason: :blocked,
          source: :webhook
        })

      {:ok, _lv, html} = live(conn, open_suppressions(reason: "blocked"))
      text = text(html)

      assert text =~ "blocked@example.com"
      refute text =~ "hard@example.com"
    end

    test "filters by an e-mail substring", %{conn: conn} do
      {:ok, _} =
        EmailSuppressions.create_from_bounce(%{
          email: "findme@example.com",
          reason: :hard_bounce,
          source: :webhook
        })

      {:ok, _} =
        EmailSuppressions.create_from_bounce(%{
          email: "other@example.com",
          reason: :hard_bounce,
          source: :webhook
        })

      {:ok, _lv, html} = live(conn, open_suppressions(search: "findme"))
      text = text(html)

      assert text =~ "findme@example.com"
      refute text =~ "other@example.com"
    end

    test "reactivates a suppressed address and records who did it", %{conn: conn, user: user} do
      {:ok, _} =
        EmailSuppressions.create_from_bounce(%{
          email: "reactivate-me@example.com",
          reason: :hard_bounce,
          source: :webhook
        })

      {:ok, lv, _html} = live(conn, open_suppressions())

      html =
        lv
        |> element(~s|a[phx-value-email="reactivate-me@example.com"]|, "Reactivate")
        |> render_click()

      assert text(html) =~ "no longer suppressed"
      assert text(html) =~ "Reactivated"

      suppression = Repo.get_by!(Plausible.EmailSuppression, email: "reactivate-me@example.com")
      assert suppression.reactivated_at
      assert suppression.reactivated_by_user_id == user.id
      refute EmailSuppressions.suppressed?("reactivate-me@example.com")
    end

    test "also activates the bounce in Postmark when there is one", %{conn: conn} do
      {:ok, _} =
        EmailSuppressions.create_from_bounce(%{
          email: "reactivate-me@example.com",
          reason: :hard_bounce,
          source: :webhook,
          postmark_bounce_id: 123,
          can_activate: true
        })

      Req.Test.stub(Postmark, fn conn ->
        assert conn.request_path == "/bounces/123/activate"
        Req.Test.json(conn, %{"Message" => "OK"})
      end)

      {:ok, lv, _html} = live(conn, open_suppressions())

      html =
        lv
        |> element(~s|a[phx-value-email="reactivate-me@example.com"]|, "Reactivate")
        |> render_click()

      assert text(html) =~ "no longer suppressed"
    end

    test "refuses to reactivate when Postmark reports the bounce can't be activated", %{
      conn: conn
    } do
      {:ok, _} =
        EmailSuppressions.create_from_bounce(%{
          email: "stuck@example.com",
          reason: :hard_bounce,
          source: :webhook,
          postmark_bounce_id: 123,
          can_activate: false
        })

      {:ok, lv, _html} = live(conn, open_suppressions())

      html =
        lv
        |> element(~s|a[phx-value-email="stuck@example.com"]|, "Reactivate")
        |> render_click()

      assert text(html) =~ "Postmark won't allow stuck@example.com to be reactivated"
      assert EmailSuppressions.suppressed?("stuck@example.com")
    end

    test "does not offer to reactivate an address that's already reactivated", %{
      conn: conn,
      user: user
    } do
      {:ok, _} =
        EmailSuppressions.create_from_bounce(%{
          email: "already-fine@example.com",
          reason: :hard_bounce,
          source: :webhook
        })

      {:ok, _} = EmailSuppressions.reactivate("already-fine@example.com", user)

      {:ok, lv, _html} = live(conn, open_suppressions())

      refute lv
             |> element(~s|a[phx-value-email="already-fine@example.com"]|)
             |> has_element?()
    end

    test "does not offer a Details popup when a suppression has no Postmark metadata", %{
      conn: conn
    } do
      {:ok, _} =
        EmailSuppressions.create_from_bounce(%{
          email: "no-metadata@example.com",
          reason: :hard_bounce,
          source: :webhook
        })

      {:ok, _lv, html} = live(conn, open_suppressions())

      assert elem_count(html, "tbody tr") == 1
      refute text_of_element(html, "tbody tr") =~ "Details"
    end
  end
end
