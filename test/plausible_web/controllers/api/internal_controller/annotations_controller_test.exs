defmodule PlausibleWeb.Api.Internal.AnnotationsControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Repo

  describe "GET /api/:domain/annotations" do
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

    test "private site returns 404 for non-member", %{conn: conn} do
      private_site = new_site()

      conn =
        get(
          conn,
          "/api/#{private_site.domain}/annotations?date_range=day&relative_date=2026-01-04"
        )

      assert json_response(conn, 404)
    end

    test "only site annotations are shown when viewing a public site, with owners info hidden",
         %{conn: conn} do
      site_owner = new_user()
      public_site = new_site(public: true, owner: site_owner)
      insert(:annotation, site: public_site, owner: site_owner, type: :site, note: "site note")
      insert(:annotation, site: public_site, owner: site_owner, type: :personal, note: "private")

      conn =
        get(
          conn,
          "/api/#{public_site.domain}/annotations?date_range=day&relative_date=2026-01-04"
        )

      assert_matches [
                       ^strict_map(%{
                         "id" => ^any(:pos_integer),
                         "note" => "site note",
                         "type" => "site",
                         "datetime" => "2026-01-04",
                         "granularity" => "date",
                         "owner_id" => nil,
                         "owner_name" => nil,
                         "inserted_at" => ^any(:iso8601_naive_datetime),
                         "updated_at" => ^any(:iso8601_naive_datetime)
                       })
                     ] = json_response(conn, 200)
    end

    test "personal annotations of the user and all site annotations are shown with annotation owner info when viewing their site, sorted by updated_at, ascending",
         %{conn: conn, user: user} do
      site = new_site()
      other_user = new_user()
      add_guest(site, user: user, role: :viewer)

      insert(:annotation,
        site: site,
        owner: user,
        type: :personal,
        note: "mine",
        inserted_at: ~U[2026-07-01 10:00:00Z],
        updated_at: ~U[2026-07-01 10:00:00Z]
      )

      insert(:annotation,
        site: site,
        owner: other_user,
        type: :personal,
        note: "not mine",
        inserted_at: ~U[2026-07-01 10:00:00Z],
        updated_at: ~U[2026-07-01 11:00:00Z]
      )

      insert(:annotation,
        site: site,
        owner: other_user,
        type: :site,
        note: "shared",
        inserted_at: ~U[2026-07-01 10:00:00Z],
        updated_at: ~U[2026-07-01 12:00:00Z]
      )

      insert(:annotation,
        site: site,
        owner: nil,
        type: :site,
        note: "dangling",
        inserted_at: ~U[2026-07-01 10:00:00Z],
        updated_at: ~U[2026-07-01 13:00:00Z]
      )

      conn = get(conn, "/api/#{site.domain}/annotations?date_range=day&relative_date=2026-01-04")

      results = json_response(conn, 200)

      assert_matches [
                       ^strict_map(%{
                         "id" => ^any(:pos_integer),
                         "note" => "dangling",
                         "type" => "site",
                         "datetime" => "2026-01-04",
                         "granularity" => "date",
                         "owner_id" => nil,
                         "owner_name" => nil,
                         "inserted_at" => ^any(:iso8601_naive_datetime),
                         "updated_at" => ^any(:iso8601_naive_datetime)
                       }),
                       ^strict_map(%{
                         "id" => ^any(:pos_integer),
                         "note" => "shared",
                         "type" => "site",
                         "datetime" => "2026-01-04",
                         "granularity" => "date",
                         "owner_id" => ^other_user.id,
                         "owner_name" => ^other_user.name,
                         "inserted_at" => ^any(:iso8601_naive_datetime),
                         "updated_at" => ^any(:iso8601_naive_datetime)
                       }),
                       ^strict_map(%{
                         "id" => ^any(:pos_integer),
                         "note" => "mine",
                         "type" => "personal",
                         "datetime" => "2026-01-04",
                         "granularity" => "date",
                         "owner_id" => ^user.id,
                         "owner_name" => ^user.name,
                         "inserted_at" => ^any(:iso8601_naive_datetime),
                         "updated_at" => ^any(:iso8601_naive_datetime)
                       })
                     ] = results
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

    test "filters minute granularity annotations to be within the UTC datetime range",
         %{conn: conn, user: user} do
      # NY is UTC-4 in June (DST).
      # Full day of 2026-06-28 -> [~U[2026-06-28 04:00:00Z], ~U[2026-06-29 03:59:59]].
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

    test "filters date granularity annotations that are within the local date range",
         %{conn: conn, user: user} do
      site = new_site(owner: user, timezone: "Asia/Tokyo")

      insert(:annotation,
        site: site,
        owner: user,
        type: :personal,
        granularity: :date,
        datetime: ~U[2026-06-29 00:00:00Z],
        note: "in range"
      )

      insert(:annotation,
        site: site,
        owner: user,
        type: :personal,
        granularity: :date,
        datetime: ~U[2026-06-30 00:00:00Z],
        note: "out of range"
      )

      conn =
        get(conn, "/api/#{site.domain}/annotations?date_range=7d&relative_date=2026-06-30")

      results = json_response(conn, 200)
      assert Enum.map(results, & &1["note"]) == ["in range"]
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

  describe "POST /api/:domain/annotations" do
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

    test "rejects missing datetime", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "feature released",
          "type" => "personal",
          "granularity" => "date"
        })

      assert json_response(conn, 400) == %{
               "error" => "date must be supplied for chosen granularity"
             }
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

    for {params, error} <- [
          {
            %{"granularity" => "date", "datetime" => "2026-01-04T00:00:00Z"},
            "date must be supplied for chosen granularity"
          },
          {
            %{"granularity" => "date", "datetime" => "2026-01-04T00:00:00"},
            "date must be supplied for chosen granularity"
          },
          {
            %{"granularity" => "date", "date" => ""},
            "date must be supplied for chosen granularity"
          },
          {
            %{"granularity" => "date", "date" => "2026-1-4"},
            "date is invalid"
          },
          {
            %{"granularity" => "date", "date" => "2026-13-45"},
            "date is invalid"
          },
          {
            %{"granularity" => "date", "date" => "not-a-date"},
            "date is invalid"
          },
          {
            %{"granularity" => "minute", "datetime" => "2026-01-04"},
            "datetime is invalid"
          },
          {
            %{"granularity" => "minute", "datetime" => "not-a-datetime"},
            "datetime is invalid"
          },
          {
            %{"granularity" => "minute", "datetime" => ""},
            "datetime must be supplied for chosen granularity"
          },
          {
            %{"granularity" => "minute", "datetime" => "2026-13-45T14:30:00Z"},
            "datetime is invalid"
          }
        ] do
      test "rejects #{inspect(params)} with error #{error}", %{conn: conn, site: site} do
        conn =
          post(
            conn,
            "/api/#{site.domain}/annotations",
            Map.merge(
              %{"note" => "feature released", "type" => "personal"},
              unquote(Macro.escape(params))
            )
          )

        assert json_response(conn, 400) == %{"error" => unquote(error)}
      end
    end

    test "accepts bare date string when granularity is date",
         %{conn: conn, site: site} do
      response =
        post(conn, "/api/#{site.domain}/annotations", %{
          "note" => "feature released",
          "type" => "personal",
          "granularity" => "date",
          "date" => "2026-01-04"
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

      reloaded = Plausible.Repo.get!(Plausible.Annotations.Annotation, response["id"])
      assert reloaded.granularity == :minute
      assert reloaded.datetime == ~U[2026-01-04 19:30:00Z]
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

  describe "PATCH /api/:domain/annotations/:annotation_id" do
    setup [:create_user, :log_in, :create_site]

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
               "error" => "datetime must be supplied for chosen granularity"
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
               "error" => "date must be supplied for chosen granularity"
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
          "date" => "2026-06-20"
        })
        |> json_response(200)

      assert response["granularity"] == "date"
      assert response["datetime"] == "2026-06-20"

      reloaded = Plausible.Repo.get!(Plausible.Annotations.Annotation, annotation.id)
      assert reloaded.granularity == :date
      assert reloaded.datetime == ~U[2026-06-20 00:00:00Z]
    end

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

      reloaded = Plausible.Repo.get!(Plausible.Annotations.Annotation, annotation.id)
      assert reloaded.granularity == :minute
      assert reloaded.datetime == ~U[2026-06-15 14:00:00Z]
    end

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
          "date" => "2026-06-15"
        })
        |> json_response(200)

      assert response["datetime"] == "2026-06-15"
    end

    for {casename, note_has_owner?} <- [
          {"dangling site note", false},
          {"site note left by other user", true}
        ] do
      test "users with site note permissions can edit a #{casename}, becoming its new owner",
           %{
             conn: conn,
             site: site,
             user: user
           } do
        note_owner =
          if(unquote(note_has_owner?),
            do:
              site.team
              |> add_member(
                user: new_user(name: "other user"),
                role: :editor
              ),
            else: nil
          )

        annotation =
          insert(:annotation,
            owner: note_owner,
            site: site,
            type: :site,
            granularity: :date,
            datetime: "2026-06-01T00:00:00Z"
          )

        response =
          patch(conn, "/api/#{site.domain}/annotations/#{annotation.id}", %{
            "note" => "updated"
          })
          |> json_response(200)

        assert_matches ^strict_map(%{
                         "id" => ^annotation.id,
                         "note" => "updated",
                         "type" =>
                           ^any(
                             :string,
                             ~r/#{annotation.type}/
                           ),
                         "granularity" =>
                           ^any(
                             :string,
                             ~r/#{annotation.granularity}/
                           ),
                         "datetime" => "2026-06-01",
                         "owner_id" => ^user.id,
                         "owner_name" => ^user.name,
                         "inserted_at" =>
                           ^any(
                             :string,
                             ~r/#{Calendar.strftime(annotation.inserted_at, "%Y-%m-%dT%H:%M:%S")}/
                           ),
                         "updated_at" => ^any(:iso8601_naive_datetime)
                       }) = response
      end
    end

    test "owner on a plan without site_annotations can demote a site annotation to personal",
         %{conn: conn, user: user} do
      subscribe_to_starter_plan(user)
      site = new_site(owner: user)
      refute Plausible.Annotations.site_annotations_available?(site)

      annotation =
        insert(:annotation,
          site: site,
          owner: user,
          type: :site,
          granularity: :date,
          datetime: ~U[2026-06-15 00:00:00Z]
        )

      response =
        patch(conn, "/api/#{site.domain}/annotations/#{annotation.id}", %{
          "type" => "personal",
          "note" => "converted after downgrade"
        })
        |> json_response(200)

      assert response["type"] == "personal"
      assert response["note"] == "converted after downgrade"

      reloaded = Plausible.Repo.get!(Plausible.Annotations.Annotation, annotation.id)
      assert reloaded.type == :personal
      assert reloaded.note == "converted after downgrade"
    end
  end
end
