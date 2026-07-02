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

      conn =
        get(
          conn,
          "/api/#{public_site.domain}/annotations?date_range=day&relative_date=2026-01-04"
        )

      assert [result] = json_response(conn, 200)
      assert result["type"] == "site"
      assert result["note"] == "site note"
    end

    test "public role response has null owner info", %{conn: conn} do
      public_site = new_site(public: true)
      site_owner = new_user()
      insert(:annotation, site: public_site, owner: site_owner, type: :site, note: "deploy")

      conn =
        get(
          conn,
          "/api/#{public_site.domain}/annotations?date_range=day&relative_date=2026-01-04"
        )

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

      conn = get(conn, "/api/#{site.domain}/annotations?date_range=day&relative_date=2026-01-04")

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

      conn = get(conn, "/api/#{site.domain}/annotations?date_range=day&relative_date=2026-01-04")

      assert [result] = json_response(conn, 200)
      assert result["owner_id"] == user.id
      assert result["owner_name"] == user.name
    end

    test "private site returns 404 for non-member", %{conn: conn} do
      private_site = new_site()

      conn =
        get(
          conn,
          "/api/#{private_site.domain}/annotations?date_range=day&relative_date=2026-01-04"
        )

      assert json_response(conn, 404)
    end
  end

  describe "GET /api/:domain/annotations - period filtering" do
    setup [:create_user, :log_in]

    test "returns 400 when date_range is missing", %{conn: conn, user: user} do
      site = new_site(owner: user)

      conn = get(conn, "/api/#{site.domain}/annotations")

      assert %{"error" => _} = json_response(conn, 400)
    end

    test "returns 400 when date_range is unrecognized", %{conn: conn, user: user} do
      site = new_site(owner: user)

      conn = get(conn, "/api/#{site.domain}/annotations?date_range=banana")

      assert %{"error" => _} = json_response(conn, 400)
    end

    test "filters out annotations outside a 28d window", %{conn: conn, user: user} do
      site = new_site(owner: user)

      insert(:annotation,
        site: site,
        owner: user,
        type: :personal,
        granularity: :date,
        datetime: ~U[2026-06-26 00:00:00Z],
        note: "in range"
      )

      insert(:annotation,
        site: site,
        owner: user,
        type: :personal,
        granularity: :date,
        datetime: ~U[2026-05-01 00:00:00Z],
        note: "out of range"
      )

      conn =
        get(conn, "/api/#{site.domain}/annotations?date_range=28d&relative_date=2026-06-29")

      results = json_response(conn, 200)
      assert Enum.map(results, & &1["note"]) == ["in range"]
    end

    test "filters by a custom [from,to] date_range", %{conn: conn, user: user} do
      site = new_site(owner: user)

      insert(:annotation,
        site: site,
        owner: user,
        type: :personal,
        granularity: :date,
        datetime: ~U[2026-06-22 00:00:00Z],
        note: "in range"
      )

      insert(:annotation,
        site: site,
        owner: user,
        type: :personal,
        granularity: :date,
        datetime: ~U[2026-06-26 00:00:00Z],
        note: "out of range"
      )

      conn =
        get(
          conn,
          "/api/#{site.domain}/annotations?date_range_start=2026-06-20&date_range_end=2026-06-25"
        )

      results = json_response(conn, 200)
      assert Enum.map(results, & &1["note"]) == ["in range"]
    end

    test "minute granularity is filtered against the UTC window of a day period",
         %{conn: conn, user: user} do
      # NY is UTC-4 in June (DST). Local 2026-06-28 -> UTC [04:00 2026-06-28, 03:59:59 2026-06-29].
      # Using a past relative_date so :day builds the full local day window
      # rather than [00:00, now], which would make the test time-of-day dependent.
      site = new_site(owner: user, timezone: "America/New_York")

      insert(:annotation,
        site: site,
        owner: user,
        type: :personal,
        granularity: :minute,
        # 11:00 local — inside the UTC window
        datetime: ~U[2026-06-28 15:00:00Z],
        note: "in window"
      )

      insert(:annotation,
        site: site,
        owner: user,
        type: :personal,
        granularity: :minute,
        # next-day 01:00 local — past the UTC window end
        datetime: ~U[2026-06-29 05:00:00Z],
        note: "past window"
      )

      conn =
        get(conn, "/api/#{site.domain}/annotations?date_range=day&relative_date=2026-06-28")

      results = json_response(conn, 200)
      assert Enum.map(results, & &1["note"]) == ["in window"]
    end

    test "date-granularity annotation for the dashboard's local date is included even though its UTC moment falls outside the UTC window",
         %{conn: conn, user: user} do
      # Date-granularity annotations store UTC midnight of the intended local
      # date, so the stored 2026-06-29T00:00:00Z is *outside* NY's UTC window
      # for local 2026-06-29 ([04:00, next 03:59:59]). It must still be returned
      # because its local date matches the dashboard's local date range.
      site = new_site(owner: user, timezone: "America/New_York")

      insert(:annotation,
        site: site,
        owner: user,
        type: :personal,
        granularity: :date,
        datetime: ~U[2026-06-29 00:00:00Z],
        note: "today date-annotation"
      )

      conn =
        get(conn, "/api/#{site.domain}/annotations?date_range=day&relative_date=2026-06-29")

      results = json_response(conn, 200)
      assert Enum.map(results, & &1["note"]) == ["today date-annotation"]
    end

    test "returns both date and minute annotations when both fall inside the period",
         %{conn: conn, user: user} do
      site = new_site(owner: user)

      insert(:annotation,
        site: site,
        owner: user,
        type: :personal,
        granularity: :date,
        datetime: ~U[2026-06-25 00:00:00Z],
        note: "date"
      )

      insert(:annotation,
        site: site,
        owner: user,
        type: :personal,
        granularity: :minute,
        datetime: ~U[2026-06-26 10:30:00Z],
        note: "minute"
      )

      conn =
        get(
          conn,
          "/api/#{site.domain}/annotations?date_range_start=2026-06-20&date_range_end=2026-06-29"
        )

      results = json_response(conn, 200)
      notes = results |> Enum.map(& &1["note"]) |> Enum.sort()
      assert notes == ["date", "minute"]
    end

    test "fetches annotations for realtime date_range", %{conn: conn, user: user} do
      site = new_site(owner: user)

      insert(:annotation,
        site: site,
        owner: user,
        type: :personal,
        granularity: :minute,
        datetime: DateTime.utc_now(),
        note: "now"
      )

      conn = get(conn, "/api/#{site.domain}/annotations?date_range=realtime")

      results = json_response(conn, 200)
      assert Enum.map(results, & &1["note"]) == ["now"]
    end
  end

  describe "POST /api/:domain/annotations - datetime coercion" do
    setup [:create_user, :log_in, :create_site]

    test "accepts bare date string when granularity is date",
         %{conn: conn, site: site} do
      response =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "feature released",
          "type" => "personal",
          "granularity" => "date",
          "datetime" => "2026-01-04"
        })
        |> json_response(200)

      assert_matches ^strict_map(%{
                       "id" => ^any(:pos_integer),
                       "note" => "feature released",
                       "type" => "personal",
                       "granularity" => "date",
                       "datetime" => "2026-01-04",
                       "owner_id" => ^any(:pos_integer),
                       "owner_name" => ^any(:string),
                       "inserted_at" => ^any(:iso8601_naive_datetime),
                       "updated_at" => ^any(:iso8601_naive_datetime)
                     }) = response
    end

    test "rejects full datetime string when granularity is date",
         %{conn: conn, site: site} do
      conn =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "feature released",
          "type" => "personal",
          "granularity" => "date",
          "datetime" => "2026-01-04T00:00:00Z"
        })

      assert json_response(conn, 400) == %{"error" => "datetime is invalid for granularity"}
    end

    test "accepts full datetime string when granularity is minute",
         %{conn: conn, site: site} do
      # Site is Etc/UTC by default; UTC moment is returned as naive local time
      response =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "feature released",
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
          "note" => "feature released",
          "type" => "personal",
          "granularity" => "minute",
          "datetime" => "2026-01-04"
        })

      assert json_response(conn, 400) == %{"error" => "datetime is invalid for granularity"}
    end

    test "rejects invalid calendar date when granularity is date",
         %{conn: conn, site: site} do
      conn =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "feature released",
          "type" => "personal",
          "granularity" => "date",
          "datetime" => "2026-13-45"
        })

      assert json_response(conn, 400) == %{"error" => "datetime is invalid for granularity"}
    end

    test "rejects non-date string when granularity is date",
         %{conn: conn, site: site} do
      conn =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "feature released",
          "type" => "personal",
          "granularity" => "date",
          "datetime" => "not-a-date"
        })

      assert json_response(conn, 400) == %{"error" => "datetime is invalid for granularity"}
    end

    test "rejects non-datetime string when granularity is minute",
         %{conn: conn, site: site} do
      conn =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "feature released",
          "type" => "personal",
          "granularity" => "minute",
          "datetime" => "not-a-datetime"
        })

      assert json_response(conn, 400) == %{"error" => "datetime is invalid for granularity"}
    end

    test "rejects empty datetime string when granularity is date",
         %{conn: conn, site: site} do
      conn =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "feature released",
          "type" => "personal",
          "granularity" => "date",
          "datetime" => ""
        })

      assert json_response(conn, 400) == %{"error" => "datetime is invalid for granularity"}
    end

    test "rejects empty datetime string when granularity is minute",
         %{conn: conn, site: site} do
      conn =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "feature released",
          "type" => "personal",
          "granularity" => "minute",
          "datetime" => ""
        })

      assert json_response(conn, 400) == %{"error" => "datetime is invalid for granularity"}
    end

    test "rejects date shorter than 10 characters when granularity is date",
         %{conn: conn, site: site} do
      conn =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "feature released",
          "type" => "personal",
          "granularity" => "date",
          "datetime" => "2026-1-4"
        })

      assert json_response(conn, 400) == %{"error" => "datetime is invalid for granularity"}
    end

    test "rejects invalid calendar datetime when granularity is minute",
         %{conn: conn, site: site} do
      conn =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "feature released",
          "type" => "personal",
          "granularity" => "minute",
          "datetime" => "2026-13-45T14:30:00Z"
        })

      assert json_response(conn, 400) == %{"error" => "datetime is invalid for granularity"}
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
          "note" => "feature released",
          "type" => "personal",
          "granularity" => "minute",
          "datetime" => "2026-01-04T14:30:00"
        })
        |> json_response(200)

      assert response["datetime"] == "2026-01-04T14:30:00"
    end

    test "rejects naive datetime when granularity is date",
         %{conn: conn, user: user} do
      site = new_site(owner: user, timezone: "America/New_York")

      conn =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "feature released",
          "type" => "personal",
          "granularity" => "date",
          "datetime" => "2026-01-04T00:00:00"
        })

      assert json_response(conn, 400) == %{"error" => "datetime is invalid for granularity"}
    end

    test "UTC datetime string is stored as UTC and returned as site local time",
         %{conn: conn, user: user} do
      # America/New_York is UTC-5 in January, so 14:30 UTC = 09:30 local
      site = new_site(owner: user, timezone: "America/New_York")

      response =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "feature released",
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

      assert json_response(conn, 400) == %{"error" => "datetime is invalid for granularity"}
    end

    test "rejects full datetime string when granularity switched to date",
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
          "granularity" => "date",
          "datetime" => "2026-06-15T10:00:00Z"
        })

      assert json_response(conn, 400) == %{"error" => "datetime is invalid for granularity"}
    end

    test "rejects granularity change from date to minute without a new datetime",
         %{conn: conn, site: site, user: user} do
      annotation =
        insert(:annotation,
          site: site,
          owner: user,
          type: :personal,
          granularity: :date,
          datetime: ~U[2026-06-15 00:00:00Z]
        )

      conn =
        patch(conn, "/api/#{site.domain}/annotations/#{annotation.id}", %{
          "granularity" => "minute"
        })

      assert json_response(conn, 400) == %{
               "error" => "datetime must be supplied when granularity changes"
             }

      reloaded = Plausible.Repo.get!(Plausible.Annotations.Annotation, annotation.id)
      assert reloaded.granularity == :date
      assert reloaded.datetime == ~U[2026-06-15 00:00:00Z]
    end

    test "rejects granularity change from minute to date without a new datetime",
         %{conn: conn, site: site, user: user} do
      annotation =
        insert(:annotation,
          site: site,
          owner: user,
          type: :personal,
          granularity: :minute,
          datetime: ~U[2026-06-15 14:30:00Z]
        )

      conn =
        patch(conn, "/api/#{site.domain}/annotations/#{annotation.id}", %{
          "granularity" => "date"
        })

      assert json_response(conn, 400) == %{
               "error" => "datetime must be supplied when granularity changes"
             }

      reloaded = Plausible.Repo.get!(Plausible.Annotations.Annotation, annotation.id)
      assert reloaded.granularity == :minute
      assert reloaded.datetime == ~U[2026-06-15 14:30:00Z]
    end

    test "accepts granularity change from date to minute with a new datetime",
         %{conn: conn, site: site, user: user} do
      annotation =
        insert(:annotation,
          site: site,
          owner: user,
          type: :personal,
          granularity: :date,
          datetime: ~U[2026-06-15 00:00:00Z]
        )

      response =
        patch(conn, "/api/#{site.domain}/annotations/#{annotation.id}", %{
          "granularity" => "minute",
          "datetime" => "2026-06-15T14:30:00Z"
        })
        |> json_response(200)

      assert response["granularity"] == "minute"
      assert response["datetime"] == "2026-06-15T14:30:00"

      reloaded = Plausible.Repo.get!(Plausible.Annotations.Annotation, annotation.id)
      assert reloaded.granularity == :minute
      assert reloaded.datetime == ~U[2026-06-15 14:30:00Z]
    end

    test "accepts granularity change from minute to date with a new datetime",
         %{conn: conn, site: site, user: user} do
      annotation =
        insert(:annotation,
          site: site,
          owner: user,
          type: :personal,
          granularity: :minute,
          datetime: ~U[2026-06-15 14:30:00Z]
        )

      response =
        patch(conn, "/api/#{site.domain}/annotations/#{annotation.id}", %{
          "granularity" => "date",
          "datetime" => "2026-06-20"
        })
        |> json_response(200)

      assert response["granularity"] == "date"
      assert response["datetime"] == "2026-06-20"

      reloaded = Plausible.Repo.get!(Plausible.Annotations.Annotation, annotation.id)
      assert reloaded.granularity == :date
      assert reloaded.datetime == ~U[2026-06-20 00:00:00Z]
    end
  end

  describe "POST /api/:domain/annotations - required fields and length" do
    setup [:create_user, :log_in, :create_site]

    test "rejects missing note", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/#{site.domain}/annotations", %{
          "type" => "personal",
          "granularity" => "date",
          "datetime" => "2026-01-04"
        })

      assert json_response(conn, 400) == %{"error" => "note can't be blank"}
    end

    test "rejects empty note", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "",
          "type" => "personal",
          "granularity" => "date",
          "datetime" => "2026-01-04"
        })

      assert json_response(conn, 400) == %{"error" => "note can't be blank"}
    end

    test "rejects note over 255 bytes", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => String.duplicate("a", 256),
          "type" => "personal",
          "granularity" => "date",
          "datetime" => "2026-01-04"
        })

      assert json_response(conn, 400) == %{"error" => "note should be at most 255 byte(s)"}
    end

    test "accepts note of exactly 255 bytes", %{conn: conn, site: site} do
      response =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => String.duplicate("a", 255),
          "type" => "personal",
          "granularity" => "date",
          "datetime" => "2026-01-04"
        })
        |> json_response(200)

      assert response["note"] == String.duplicate("a", 255)
    end

    test "rejects missing datetime", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "feature released",
          "type" => "personal",
          "granularity" => "date"
        })

      assert json_response(conn, 400) == %{"error" => "datetime can't be blank"}
    end

    test "rejects unknown granularity", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "feature released",
          "type" => "personal",
          "granularity" => "hour",
          "datetime" => "2026-01-04T00:00:00Z"
        })

      assert json_response(conn, 400) == %{"error" => "granularity is invalid"}
    end

    test "rejects missing granularity", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "feature released",
          "type" => "personal",
          "datetime" => "2026-01-04T00:00:00Z"
        })

      assert json_response(conn, 400) == %{"error" => "granularity can't be blank"}
    end

    test "rejects unknown type as insufficient permissions", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "feature released",
          "type" => "team",
          "granularity" => "date",
          "datetime" => "2026-01-04"
        })

      assert json_response(conn, 403) == %{
               "error" => "Not enough permissions to create annotation"
             }
    end
  end
end
