defmodule PlausibleWeb.Api.Internal.AnnotationsControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Repo

  describe "GET /api/:domain/annotations - index" do
    setup [:create_user, :log_in]

    test "public role sees only site annotations, not personal ones", %{conn: conn} do
      public_site = new_site(public: true)
      site_owner = new_user()
      insert(:annotation, site: public_site, owner: site_owner, type: :site, note: "site note")
      insert(:annotation, site: public_site, owner: site_owner, type: :personal, note: "private")

      conn = get(conn, "/api/#{public_site.domain}/annotations")

      assert [result] = json_response(conn, 200)
      assert result["type"] == "site"
      assert result["note"] == "site note"
    end

    test "public role response has null owner info", %{conn: conn} do
      public_site = new_site(public: true)
      site_owner = new_user()
      insert(:annotation, site: public_site, owner: site_owner, type: :site, note: "deploy")

      conn = get(conn, "/api/#{public_site.domain}/annotations")

      assert [result] = json_response(conn, 200)
      assert result["owner_id"] == nil
      assert result["owner_name"] == nil
    end

    test "authenticated viewer sees their own personal annotations and all site annotations",
         %{conn: conn, user: user} do
      site = new_site()
      other_user = new_user()
      add_guest(site, user: user, role: :viewer)
      insert(:annotation, site: site, owner: user, type: :personal, note: "mine")
      insert(:annotation, site: site, owner: other_user, type: :personal, note: "not mine")
      insert(:annotation, site: site, owner: other_user, type: :site, note: "shared")

      conn = get(conn, "/api/#{site.domain}/annotations")

      assert results = json_response(conn, 200)
      assert length(results) == 2
      notes = Enum.map(results, & &1["note"])
      assert "mine" in notes
      assert "shared" in notes
      refute "not mine" in notes
    end

    test "authenticated owner response includes owner info", %{conn: conn, user: user} do
      site = new_site(owner: user)
      insert(:annotation, site: site, owner: user, type: :site, note: "deploy")

      conn = get(conn, "/api/#{site.domain}/annotations")

      assert [result] = json_response(conn, 200)
      assert result["owner_id"] == user.id
      assert result["owner_name"] == user.name
    end

    test "private site returns 404 for non-member", %{conn: conn} do
      private_site = new_site()

      conn = get(conn, "/api/#{private_site.domain}/annotations")

      assert json_response(conn, 404)
    end
  end

  describe "POST /api/:domain/annotations - datetime coercion" do
    setup [:create_user, :log_in, :create_site]

    test "accepts bare date string when granularity is date",
         %{conn: conn, site: site} do
      response =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "deploys",
          "type" => "personal",
          "granularity" => "date",
          "datetime" => "2026-01-04"
        })
        |> json_response(200)

      assert_matches ^strict_map(%{
                       "id" => ^any(:pos_integer),
                       "note" => "deploys",
                       "type" => "personal",
                       "granularity" => "date",
                       "datetime" => "2026-01-04",
                       "owner_id" => ^any(:pos_integer),
                       "owner_name" => ^any(:string),
                       "inserted_at" => ^any(:iso8601_naive_datetime),
                       "updated_at" => ^any(:iso8601_naive_datetime)
                     }) = response
    end

    test "accepts full datetime string when granularity is date",
         %{conn: conn, site: site} do
      response =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "deploys",
          "type" => "personal",
          "granularity" => "date",
          "datetime" => "2026-01-04T00:00:00Z"
        })
        |> json_response(200)

      assert response["datetime"] == "2026-01-04"
    end

    test "accepts full datetime string when granularity is minute",
         %{conn: conn, site: site} do
      # Site is Etc/UTC by default; UTC moment is returned as naive local time
      response =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "deploys",
          "type" => "personal",
          "granularity" => "minute",
          "datetime" => "2026-01-04T14:32:00Z"
        })
        |> json_response(200)

      assert response["datetime"] == "2026-01-04T14:32:00"
    end

    test "rejects bare date string when granularity is minute",
         %{conn: conn, site: site} do
      conn =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "deploys",
          "type" => "personal",
          "granularity" => "minute",
          "datetime" => "2026-01-04"
        })

      assert %{"error" => _} = json_response(conn, 400)
    end

    test "rejects invalid calendar date when granularity is date",
         %{conn: conn, site: site} do
      conn =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "deploys",
          "type" => "personal",
          "granularity" => "date",
          "datetime" => "2026-13-45"
        })

      assert %{"error" => _} = json_response(conn, 400)
    end

    test "rejects non-date string when granularity is date",
         %{conn: conn, site: site} do
      conn =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "deploys",
          "type" => "personal",
          "granularity" => "date",
          "datetime" => "not-a-date"
        })

      assert %{"error" => _} = json_response(conn, 400)
    end
  end

  describe "POST /api/:domain/annotations - naive local time coercion" do
    setup [:create_user, :log_in]

    test "converts naive local time to UTC and returns it back as local time",
         %{conn: conn, user: user} do
      # America/New_York is UTC-5 in January; input and output should be the same
      # local time (round-trip), while the DB stores the UTC equivalent.
      site = new_site(owner: user, timezone: "America/New_York")

      response =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "deploys",
          "type" => "personal",
          "granularity" => "minute",
          "datetime" => "2026-01-04T14:30:00"
        })
        |> json_response(200)

      assert response["datetime"] == "2026-01-04T14:30:00"
    end

    test "naive datetime with date granularity returns date without timezone shift",
         %{conn: conn, user: user} do
      site = new_site(owner: user, timezone: "America/New_York")

      response =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "deploys",
          "type" => "personal",
          "granularity" => "date",
          "datetime" => "2026-01-04T00:00:00"
        })
        |> json_response(200)

      assert response["datetime"] == "2026-01-04"
    end

    test "UTC datetime string is stored as UTC and returned as site local time",
         %{conn: conn, user: user} do
      # America/New_York is UTC-5 in January, so 14:30 UTC = 09:30 local
      site = new_site(owner: user, timezone: "America/New_York")

      response =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "deploys",
          "type" => "personal",
          "granularity" => "minute",
          "datetime" => "2026-01-04T14:30:00Z"
        })
        |> json_response(200)

      assert response["datetime"] == "2026-01-04T09:30:00"
    end
  end

  describe "PATCH /api/:domain/annotations/:annotation_id - naive local time coercion" do
    setup [:create_user, :log_in]

    test "converts naive local time to UTC and returns it back as local time",
         %{conn: conn, user: user} do
      # America/New_York is UTC-4 in June (DST), so input and output are the same
      site = new_site(owner: user, timezone: "America/New_York")

      annotation =
        insert(:annotation,
          site: site,
          owner: user,
          type: :personal,
          granularity: :minute,
          datetime: ~U[2026-01-01 00:00:00Z]
        )

      response =
        patch(conn, "/api/#{site.domain}/annotations/#{annotation.id}", %{
          "granularity" => "minute",
          "datetime" => "2026-06-15T10:00:00"
        })
        |> json_response(200)

      assert response["datetime"] == "2026-06-15T10:00:00"
    end
  end

  describe "PATCH /api/:domain/annotations/:annotation_id - datetime coercion" do
    setup [:create_user, :log_in, :create_site]

    test "accepts bare date string when granularity is date",
         %{conn: conn, site: site, user: user} do
      annotation =
        insert(:annotation,
          site: site,
          owner: user,
          type: :personal,
          granularity: :date,
          datetime: ~U[2026-01-01 00:00:00Z]
        )

      response =
        patch(conn, "/api/#{site.domain}/annotations/#{annotation.id}", %{
          "granularity" => "date",
          "datetime" => "2026-06-15"
        })
        |> json_response(200)

      assert response["datetime"] == "2026-06-15"
    end

    test "rejects bare date string when granularity is minute",
         %{conn: conn, site: site, user: user} do
      annotation =
        insert(:annotation,
          site: site,
          owner: user,
          type: :personal,
          granularity: :minute,
          datetime: ~U[2026-01-01 10:00:00Z]
        )

      conn =
        patch(conn, "/api/#{site.domain}/annotations/#{annotation.id}", %{
          "granularity" => "minute",
          "datetime" => "2026-06-15"
        })

      assert %{"error" => _} = json_response(conn, 400)
    end
  end
end
