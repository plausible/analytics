defmodule PlausibleWeb.Api.Internal.SegmentsControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Repo
  use Plausible.Teams.Test

  describe "GET /api/:domain/segments" do
    setup [:create_user, :log_in, :create_site]

    test "returns empty list when no segments", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/#{site.domain}/segments")

      assert json_response(conn, 200) == []
    end

    test "returns site segments list when looking at a public dashboard", %{conn: conn} do
      other_user = new_user()
      site = new_site(owner: other_user, public: true)

      site_segments =
        insert_list(2, :segment,
          site: site,
          owner: other_user,
          type: :site,
          name: "other site segment"
        )

      insert_list(10, :segment,
        site: site,
        owner: other_user,
        type: :personal,
        name: "other user personal segment"
      )

      conn = get(conn, "/api/#{site.domain}/segments")

      assert json_response(conn, 200) ==
               Enum.reverse(
                 Enum.map(site_segments, fn s ->
                   %{
                     "id" => s.id,
                     "name" => s.name,
                     "type" => Atom.to_string(s.type),
                     "inserted_at" => Calendar.strftime(s.inserted_at, "%Y-%m-%d %H:%M:%S"),
                     "updated_at" => Calendar.strftime(s.updated_at, "%Y-%m-%d %H:%M:%S"),
                     "owner_id" => nil,
                     "owner_name" => nil,
                     "segment_data" => nil
                   }
                 end)
               )
    end

    test "forbids owners on growth plan from seeing site segments", %{
      conn: conn,
      user: user,
      site: site
    } do
      user |> subscribe_to_growth_plan()

      insert_list(2, :segment,
        site: site,
        owner: user,
        type: :site,
        name: "site segment"
      )

      conn =
        get(conn, "/api/#{site.domain}/segments")

      assert json_response(conn, 200) == []
    end

    for role <- [:viewer, :owner] do
      test "returns list with personal and site segments for #{role}, avoiding segments from other site",
           %{conn: conn, user: user, site: site} do
        other_user = new_user(name: "Other User")
        other_site = new_site(owner: other_user, team: team_of(user))

        insert_list(2, :segment,
          site: other_site,
          owner: user,
          type: :site,
          name: "other site segment"
        )

        insert_list(10, :segment,
          site: site,
          owner: other_user,
          type: :personal,
          name: "other user personal segment"
        )

        personal_segment =
          insert(:segment,
            site: site,
            owner: user,
            type: :personal,
            name: "a personal segment"
          )
          |> Map.put(:owner_name, user.name)

        emea_site_segment =
          insert(:segment,
            site: site,
            owner: other_user,
            type: :site,
            name: "EMEA region"
          )
          |> Map.put(:owner_name, other_user.name)

        apac_site_segment =
          insert(:segment,
            site: site,
            owner: user,
            type: :site,
            name: "APAC region"
          )
          |> Map.put(:owner_name, user.name)

        dangling_site_segment =
          insert(:segment,
            site: site,
            owner: nil,
            type: :site,
            name: "Another region"
          )
          |> Map.put(:owner_name, nil)

        conn =
          get(conn, "/api/#{site.domain}/segments")

        assert json_response(conn, 200) ==
                 Enum.map(
                   [
                     dangling_site_segment,
                     apac_site_segment,
                     emea_site_segment,
                     personal_segment
                   ],
                   fn s ->
                     %{
                       "id" => s.id,
                       "name" => s.name,
                       "type" => Atom.to_string(s.type),
                       "owner_id" => s.owner_id,
                       "owner_name" => s.owner_name,
                       "inserted_at" => Calendar.strftime(s.inserted_at, "%Y-%m-%d %H:%M:%S"),
                       "updated_at" => Calendar.strftime(s.updated_at, "%Y-%m-%d %H:%M:%S"),
                       "segment_data" => nil
                     }
                   end
                 )
      end
    end
  end

  describe "GET /api/:domain/segments/:segment_id" do
    setup [:create_user, :create_site, :log_in]

    test "serves 404 when invalid segment key used", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/#{site.domain}/segments/any-id")

      assert json_response(conn, 404) == %{"error" => "Segment not found with ID \"any-id\""}
    end

    test "serves 404 when no segment found", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/#{site.domain}/segments/100100")

      assert json_response(conn, 404) == %{"error" => "Segment not found with ID \"100100\""}
    end

    test "serves 404 when segment is for another site", %{conn: conn, site: site, user: user} do
      other_site = new_site(owner: user)

      segment =
        insert(:segment,
          site: other_site,
          owner: user,
          type: :site,
          name: "any"
        )

      conn =
        get(conn, "/api/#{site.domain}/segments/#{segment.id}")

      assert json_response(conn, 404) == %{
               "error" => "Segment not found with ID \"#{segment.id}\""
             }
    end

    test "serves 404 for viewing contents of site segments for viewers of public dashboards",
         %{
           conn: conn
         } do
      site = new_site(public: true)
      other_user = add_guest(site, user: new_user(), role: :editor)

      segment =
        insert(:segment,
          type: :site,
          owner: other_user,
          site: site,
          name: "any"
        )

      conn =
        get(conn, "/api/#{site.domain}/segments/#{segment.id}")

      assert json_response(conn, 403) == %{
               "error" => "Not enough permissions to get segment data"
             }
    end

    test "serves 404 when user is not the segment owner and segment is personal",
         %{
           conn: conn,
           site: site
         } do
      other_user = add_guest(site, role: :editor)

      segment =
        insert(:segment,
          type: :personal,
          owner: other_user,
          site: site,
          name: "any"
        )

      conn =
        get(conn, "/api/#{site.domain}/segments/#{segment.id}")

      assert json_response(conn, 404) == %{
               "error" => "Segment not found with ID \"#{segment.id}\""
             }
    end

    test "serves 200 with segment when user is not the segment owner and segment is not personal",
         %{
           conn: conn,
           user: user
         } do
      site = new_site(owner: user, timezone: "Asia/Tokyo")
      other_user = add_guest(site, role: :editor)

      segment =
        insert(:segment,
          type: :site,
          owner: other_user,
          site: site,
          name: "any",
          inserted_at: "2024-09-01T22:00:00.000Z",
          updated_at: "2024-09-01T23:00:00.000Z"
        )

      conn =
        get(conn, "/api/#{site.domain}/segments/#{segment.id}")

      assert json_response(conn, 200) == %{
               "id" => segment.id,
               "owner_id" => other_user.id,
               "owner_name" => other_user.name,
               "name" => segment.name,
               "type" => Atom.to_string(segment.type),
               "segment_data" => segment.segment_data,
               "inserted_at" => "2024-09-02 07:00:00",
               "updated_at" => "2024-09-02 08:00:00"
             }
    end

    test "serves 200 with segment when user is segment owner", %{
      conn: conn,
      site: site,
      user: user
    } do
      segment =
        insert(:segment,
          site: site,
          name: "any",
          owner: user,
          type: :personal
        )

      conn =
        get(conn, "/api/#{site.domain}/segments/#{segment.id}")

      assert json_response(conn, 200) == %{
               "id" => segment.id,
               "owner_id" => user.id,
               "owner_name" => user.name,
               "name" => segment.name,
               "type" => Atom.to_string(segment.type),
               "segment_data" => segment.segment_data,
               "inserted_at" => Calendar.strftime(segment.inserted_at, "%Y-%m-%d %H:%M:%S"),
               "updated_at" => Calendar.strftime(segment.updated_at, "%Y-%m-%d %H:%M:%S")
             }
    end
  end

  describe "POST /api/:domain/segments" do
    setup [:create_user, :log_in, :create_site]

    test "forbids viewers from creating site segments", %{conn: conn, user: user} do
      site = new_site()
      add_guest(site, user: user, role: :viewer)

      conn =
        post(conn, "/api/#{site.domain}/segments", %{
          "type" => "site",
          "segment_data" => %{"filters" => [["is", "visit:entry_page", ["/blog"]]]},
          "name" => "any name"
        })

      assert json_response(conn, 403) == %{
               "error" => "Not enough permissions to create segment"
             }
    end

    test "forbids owners on growth plan from creating site segments", %{
      conn: conn,
      user: user,
      site: site
    } do
      user |> subscribe_to_growth_plan()

      conn =
        post(conn, "/api/#{site.domain}/segments", %{
          "type" => "site",
          "segment_data" => %{"filters" => [["is", "visit:entry_page", ["/blog"]]]},
          "name" => "any name"
        })

      assert json_response(conn, 403) == %{
               "error" => "Not enough permissions to create segment"
             }
    end

    test "forbids users from creating segments with invalid filters",
         %{
           conn: conn,
           site: site
         } do
      conn =
        post(conn, "/api/#{site.domain}/segments", %{
          "type" => "site",
          "segment_data" => %{
            "filters" => [["is", "entry_page", ["/blog"]]]
          },
          "name" => "any name"
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "segment_data #/filters/0: Invalid filter [\"is\", \"entry_page\", [\"/blog\"]]"
             }
    end

    for %{role: role, type: type} <- [
          %{role: :viewer, type: :personal},
          %{role: :editor, type: :personal},
          %{role: :editor, type: :site}
        ] do
      test "#{role} can create segment with type \"#{type}\" successfully",
           %{conn: conn, user: user} do
        site = new_site()
        add_guest(site, user: user, role: unquote(role))
        insert(:goal, site: site, event_name: "Conversion")

        response =
          post(conn, "/api/#{site.domain}/segments", %{
            "name" => "Some segment",
            "type" => "#{unquote(type)}",
            "segment_data" => %{
              "filters" => [
                ["is", "visit:entry_page", ["/blog"]],
                ["has_not_done", ["is", "event:goal", ["Conversion"]]]
              ]
            }
          })
          |> json_response(200)

        assert_matches ^strict_map(%{
                         "id" => ^any(:pos_integer),
                         "name" => "Some segment",
                         "type" => ^"#{unquote(type)}",
                         "segment_data" =>
                           ^strict_map(%{
                             "filters" => [
                               ["is", "visit:entry_page", ["/blog"]],
                               ["has_not_done", ["is", "event:goal", ["Conversion"]]]
                             ]
                           }),
                         "owner_id" => ^user.id,
                         "owner_name" => ^user.name,
                         "inserted_at" => ^any(:iso8601_naive_datetime),
                         "updated_at" => ^any(:iso8601_naive_datetime)
                       }) = response

        assert response["inserted_at"] == response["updated_at"]

        verify_segment_in_db(%Plausible.Segments.Segment{
          id: response["id"],
          name: response["name"],
          type: String.to_existing_atom(response["type"]),
          segment_data: response["segment_data"],
          owner_id: response["owner_id"],
          site_id: site.id,
          inserted_at: NaiveDateTime.from_iso8601!(response["inserted_at"]),
          updated_at: NaiveDateTime.from_iso8601!(response["updated_at"])
        })
      end
    end
  end

  describe "PATCH /api/:domain/segments/:segment_id" do
    setup [:create_user, :create_site, :log_in]

    for {current_type, patch_type} <- [
          {:personal, :site},
          {:site, :personal}
        ] do
      test "prevents viewers from updating segments with current type #{current_type} with #{patch_type}",
           %{
             conn: conn,
             user: user
           } do
        site = new_site()
        add_guest(site, user: user, role: :viewer)

        %{id: segment_id} =
          insert(:segment,
            site: site,
            name: "any",
            type: unquote(current_type),
            owner: user
          )

        conn =
          patch(conn, "/api/#{site.domain}/segments/#{segment_id}", %{
            "name" => "updated name",
            "type" => "#{unquote(patch_type)}"
          })

        assert json_response(conn, 403) == %{
                 "error" => "Not enough permissions to edit segment"
               }
      end
    end

    for {filters, expected_error} <- [
          {[], "segment_data property \"filters\" must be an array with at least one member"},
          {[["foo", "bar"]], "segment_data #/filters/0: Invalid filter [\"foo\", \"bar\"]"},
          {[["not", ["is", "visit:entry_page", ["/campaigns/:campaign_name"]]]],
           "segment_data Invalid filters. Deep filters are not supported."},
          {[
             [
               "or",
               [
                 ["is", "event:goal", ["any goal"]],
                 ["is", "visit:entry_page", ["/campaigns/:campaign_name"]]
               ]
             ]
           ],
           "segment_data Invalid filters. Dimension `event:goal` can only be filtered at the top level."}
        ] do
      test "prevents owners from updating segments to invalid filters #{inspect(filters)} with error 400",
           %{
             conn: conn,
             user: user,
             site: site
           } do
        segment =
          insert(:segment,
            site: site,
            name: "any name",
            type: :personal,
            owner: user
          )

        conn =
          patch(conn, "/api/#{site.domain}/segments/#{segment.id}", %{
            "segment_data" => %{"filters" => unquote(filters)}
          })

        assert json_response(conn, 400) == %{
                 "error" => unquote(expected_error)
               }
      end
    end

    test "prevents editors from updating segments name beyond 255 characters with error 400",
         %{
           conn: conn,
           user: user,
           site: site
         } do
      segment =
        insert(:segment,
          site: site,
          name: "any name",
          type: :personal,
          owner: user
        )

      conn =
        patch(conn, "/api/#{site.domain}/segments/#{segment.id}", %{
          "name" => String.duplicate("a", 256)
        })

      assert json_response(conn, 400) == %{
               "error" => "name should be at most 255 byte(s)"
             }
    end

    test "updating a segment containing a goal that has been deleted, with the deleted goal still in filters, fails",
         %{
           conn: conn,
           user: user,
           site: site
         } do
      segment =
        insert(:segment,
          site: site,
          name: "any name",
          type: :personal,
          owner: user,
          segment_data: %{"filters" => [["is", "event:goal", ["Signup"]]]}
        )

      conn =
        patch(conn, "/api/#{site.domain}/segments/#{segment.id}", %{
          "segment_data" => %{
            "filters" => [["is", "event:goal", ["Signup"]], ["is", "event:page", ["/register"]]]
          }
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "segment_data Invalid filters. The goal `Signup` is not configured for this site. Find out how to configure goals here: https://plausible.io/docs/stats-api#filtering-by-goals"
             }
    end

    test "a segment containing a goal that has been deleted can be updated to not contain the goal",
         %{
           conn: conn,
           user: user,
           site: site
         } do
      segment =
        insert(:segment,
          site: site,
          name: "any name",
          type: :personal,
          owner: user,
          segment_data: %{"filters" => [["is", "event:goal", ["Signup"]]]}
        )

      insert(:goal, site: site, event_name: "a new goal")

      response =
        patch(conn, "/api/#{site.domain}/segments/#{segment.id}", %{
          "segment_data" => %{
            "filters" => [["is", "event:goal", ["a new goal"]]]
          }
        })
        |> json_response(200)

      assert_matches ^strict_map(%{
                       "id" => ^segment.id,
                       "name" => ^segment.name,
                       "type" => ^any(:string, ~r/#{segment.type}/),
                       "segment_data" =>
                         ^strict_map(%{
                           "filters" => [
                             ["is", "event:goal", ["a new goal"]]
                           ]
                         }),
                       "owner_id" => ^user.id,
                       "owner_name" => ^user.name,
                       "inserted_at" => ^any(:iso8601_naive_datetime),
                       "updated_at" => ^any(:iso8601_naive_datetime)
                     }) = response
    end

    test "editors can update a segment", %{conn: conn, user: user} do
      site = new_site()
      add_guest(site, user: user, role: :editor)

      segment =
        insert(:segment,
          site: site,
          name: "original name",
          type: :site,
          owner: user,
          inserted_at: "2024-09-01T10:00:00",
          updated_at: "2024-09-01T10:00:00"
        )

      response =
        patch(conn, "/api/#{site.domain}/segments/#{segment.id}", %{
          "name" => "updated name",
          "type" => "personal"
        })
        |> json_response(200)

      assert_matches ^strict_map(%{
                       "id" => ^segment.id,
                       "name" => "updated name",
                       "type" => "personal",
                       "owner_id" => ^user.id,
                       "owner_name" => ^user.name,
                       "segment_data" => ^segment.segment_data,
                       "inserted_at" =>
                         ^any(
                           :string,
                           ~r/#{Calendar.strftime(segment.inserted_at, "%Y-%m-%d %H:%M:%S")}/
                         ),
                       "updated_at" => ^any(:iso8601_naive_datetime)
                     }) = response
    end

    test "the last editor of a dangling site segment (segment with owner_id: nil) becomes the new owner",
         %{
           conn: conn,
           user: user
         } do
      site = new_site()
      add_guest(site, user: user, role: :editor)

      segment =
        insert(:segment,
          site: site,
          name: "original name",
          type: :site,
          owner: nil
        )

      response =
        patch(conn, "/api/#{site.domain}/segments/#{segment.id}", %{"name" => "updated name"})
        |> json_response(200)

      assert_matches ^strict_map(%{
                       "id" => ^segment.id,
                       "name" => "updated name",
                       "type" =>
                         ^any(
                           :string,
                           ~r/#{segment.type}/
                         ),
                       "owner_id" => ^user.id,
                       "owner_name" => ^user.name,
                       "segment_data" => ^segment.segment_data,
                       "inserted_at" =>
                         ^any(
                           :string,
                           ~r/#{Calendar.strftime(segment.inserted_at, "%Y-%m-%d %H:%M:%S")}/
                         ),
                       "updated_at" => ^any(:iso8601_naive_datetime)
                     }) = response
    end
  end

  describe "DELETE /api/:domain/segments/:segment_id" do
    setup [:create_user, :create_site, :log_in]

    test "forbids viewers from deleting site segments", %{conn: conn, user: user} do
      site = new_site()
      add_guest(site, user: user, role: :viewer)

      segment =
        insert(:segment,
          site: site,
          name: "any",
          type: :site,
          owner_id: user.id
        )

      conn =
        delete(conn, "/api/#{site.domain}/segments/#{segment.id}")

      assert json_response(conn, 403) == %{
               "error" => "Not enough permissions to delete segment"
             }

      verify_segment_in_db(segment)
    end

    test "even site owners can't delete personal segments of other users",
         %{conn: conn, site: site} do
      other_user = add_guest(site, role: :editor)

      segment =
        insert(:segment,
          site: site,
          owner_id: other_user.id,
          name: "any",
          type: :personal
        )

      conn =
        delete(conn, "/api/#{site.domain}/segments/#{segment.id}")

      assert %{"error" => "Segment not found with ID \"#{segment.id}\""} ==
               json_response(conn, 404)

      verify_segment_in_db(segment)
    end

    for %{role: role, type: type} <- [
          %{role: :viewer, type: :personal},
          %{role: :editor, type: :personal},
          %{role: :editor, type: :site}
        ] do
      test "#{role} can delete their own segment with type \"#{type}\" successfully",
           %{conn: conn, user: user} do
        site = new_site()
        add_guest(site, user: user, role: unquote(role))

        segment =
          insert(:segment,
            site: site,
            name: "any",
            type: unquote(type),
            owner: user
          )

        response =
          delete(conn, "/api/#{site.domain}/segments/#{segment.id}")
          |> json_response(200)

        assert %{
                 "owner_id" => user.id,
                 "owner_name" => user.name,
                 "id" => segment.id,
                 "name" => segment.name,
                 "segment_data" => segment.segment_data,
                 "type" => "#{unquote(type)}",
                 "inserted_at" => Calendar.strftime(segment.inserted_at, "%Y-%m-%d %H:%M:%S"),
                 "updated_at" => Calendar.strftime(segment.updated_at, "%Y-%m-%d %H:%M:%S")
               } == response

        verify_no_segment_in_db(segment)
      end
    end

    test "site owner can delete a site segment owned by someone else, even if it contains a non-existing goal",
         %{conn: conn, site: site} do
      other_user = add_guest(site, role: :editor)

      segment =
        insert(:segment,
          site: site,
          owner: other_user,
          name: "any",
          type: :site,
          segment_data: %{"filters" => [["is", "event:goal", ["non-existing goal"]]]}
        )

      response =
        delete(conn, "/api/#{site.domain}/segments/#{segment.id}")
        |> json_response(200)

      assert %{
               "owner_name" => other_user.name,
               "owner_id" => other_user.id,
               "id" => segment.id,
               "name" => segment.name,
               "segment_data" => segment.segment_data,
               "type" => "site",
               "inserted_at" => Calendar.strftime(segment.inserted_at, "%Y-%m-%d %H:%M:%S"),
               "updated_at" => Calendar.strftime(segment.updated_at, "%Y-%m-%d %H:%M:%S")
             } == response

      verify_no_segment_in_db(segment)
    end
  end

  defp verify_segment_in_db(segment) do
    uncomparable_keys = [:__meta__, :site]

    assert Map.drop(Repo.get(Plausible.Segments.Segment, segment.id), uncomparable_keys) ==
             Map.drop(segment, uncomparable_keys)
  end

  defp verify_no_segment_in_db(segment) do
    assert Repo.get(Plausible.Segments.Segment, segment.id) == nil
  end
end
