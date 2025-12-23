defmodule PlausibleWeb.Api.Internal.SegmentsControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Repo

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
               "error" => "segment_data Invalid filter '[\"is\", \"entry_page\", [\"/blog\"]]'."
             }
    end

    test "returns error when segment limit is reached", %{conn: conn, user: user, site: site} do
      insert_list(500, :segment, site: site, owner: user, type: :personal, name: "a segment")

      conn =
        post(conn, "/api/#{site.domain}/segments", %{
          "type" => "personal",
          "segment_data" => %{"filters" => [["is", "visit:entry_page", ["/blog"]]]},
          "name" => "any name"
        })

      assert json_response(conn, 403) == %{
               "error" => "Segment limit reached"
             }

      assert Repo.aggregate(
               from(segment in Plausible.Segments.Segment, where: segment.site_id == ^site.id),
               :count,
               :id
             ) == 500
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
          {[["foo", "bar"]], "segment_data Unknown operator for filter '[\"foo\", \"bar\"]'."},
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
                           ~r/#{Calendar.strftime(segment.inserted_at, "%Y-%m-%dT%H:%M:%S")}/
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
                           ~r/#{Calendar.strftime(segment.inserted_at, "%Y-%m-%dT%H:%M:%S")}/
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
                 "inserted_at" => Calendar.strftime(segment.inserted_at, "%Y-%m-%dT%H:%M:%S"),
                 "updated_at" => Calendar.strftime(segment.updated_at, "%Y-%m-%dT%H:%M:%S")
               } == response

        verify_no_segment_in_db(segment)
      end
    end

    test "deleting a segment deletes the shared links linked to it", %{
      conn: conn,
      site: site,
      user: user
    } do
      segment =
        insert(:segment,
          site: site,
          owner: user,
          name: "any",
          type: :personal,
          segment_data: %{"filters" => [["is", "event:goal", ["Signup"]]]}
        )

      other_segment =
        insert(:segment,
          site: site,
          owner: user,
          name: "other",
          type: :site,
          segment_data: %{"filters" => [["is", "event:goal", ["Signup"]]]}
        )

      shared_links_with_segments =
        insert_list(3, :shared_link,
          site: site,
          segment_id: segment.id
        )

      shared_link_with_other_segment =
        insert(:shared_link, site: site, name: "Gamma", segment_id: other_segment.id)

      shared_link_with_no_segment = insert(:shared_link, site: site, name: "Delta")

      response =
        delete(conn, "/api/#{site.domain}/segments/#{segment.id}")
        |> json_response(200)

      assert %{
               "owner_id" => user.id,
               "owner_name" => user.name,
               "id" => segment.id,
               "name" => segment.name,
               "segment_data" => segment.segment_data,
               "type" => "#{segment.type}",
               "inserted_at" => Calendar.strftime(segment.inserted_at, "%Y-%m-%dT%H:%M:%S"),
               "updated_at" => Calendar.strftime(segment.updated_at, "%Y-%m-%dT%H:%M:%S")
             } == response

      assert Repo.reload(shared_link_with_other_segment)
      assert Repo.reload(shared_link_with_no_segment)

      for link <- shared_links_with_segments do
        refute Repo.reload(link)
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
               "inserted_at" => Calendar.strftime(segment.inserted_at, "%Y-%m-%dT%H:%M:%S"),
               "updated_at" => Calendar.strftime(segment.updated_at, "%Y-%m-%dT%H:%M:%S")
             } == response

      verify_no_segment_in_db(segment)
    end
  end

  describe "GET /api/:domain/segments/:segment_id/shared-links" do
    setup [:create_user, :create_site, :log_in]

    for %{role: role} <- [
          %{role: :viewer},
          %{role: :editor},
          %{role: :admin},
          %{role: :billing},
          %{role: :owner}
        ] do
      test "#{role} can get related shared links for a segment", %{
        conn: conn,
        site: site
      } do
        user = add_member(site.team, role: unquote(role))

        segment = insert(:segment, site: site, name: "Test Segment", type: :site, owner: user)

        insert(:shared_link, site: site, name: "Shared Link 1", segment_id: segment.id)
        insert(:shared_link, site: site, name: "Shared Link 2", segment_id: segment.id)

        # Create a shared link for a different segment to ensure filtering works
        other_segment = insert(:segment, site: site, name: "Other Segment", type: :personal)
        insert(:shared_link, site: site, name: "Other Shared Link", segment_id: other_segment.id)

        # Create a shared link with no segment
        insert(:shared_link, site: site, name: "No Segment Link", segment_id: nil)

        response =
          get(conn, "/api/#{site.domain}/segments/#{segment.id}/shared-links")
          |> json_response(200)

        assert response == ["Shared Link 1", "Shared Link 2"]
      end
    end

    test "returns empty list when no shared links are related to the segment", %{
      conn: conn,
      user: user,
      site: site
    } do
      segment = insert(:segment, site: site, name: "Test Segment", type: :personal, owner: user)

      response =
        get(conn, "/api/#{site.domain}/segments/#{segment.id}/shared-links")
        |> json_response(200)

      assert response == []
    end

    test "returns empty list when giving a segment ID that doesn't exist", %{
      conn: conn,
      site: site
    } do
      response =
        get(conn, "/api/#{site.domain}/segments/9999999/shared-links")
        |> json_response(200)

      assert response == []
    end

    test "returns empty list when requesting with the segment_id of another site", %{
      conn: conn,
      site: site
    } do
      other_site = new_site()
      other_site_segment = insert(:segment, site: other_site, name: "Test Segment")

      insert(:shared_link,
        site: other_site,
        name: "Link",
        segment_id: other_site_segment.id
      )

      response =
        get(conn, "/api/#{site.domain}/segments/#{other_site_segment.id}/shared-links")
        |> json_response(200)

      assert response == []
    end

    test "returns 404 for invalid segment_id", %{conn: conn, site: site} do
      conn = get(conn, "/api/#{site.domain}/segments/invalid/shared-links")

      assert %{"error" => "Segment not found with ID \"invalid\""} ==
               json_response(conn, 404)
    end

    test "returns 403 when looking at a public site", %{conn: conn} do
      public_site = new_site(public: true)
      segment = insert(:segment, site: public_site, name: "segment", type: :site)

      conn =
        get(conn, "/api/#{public_site.domain}/segments/#{segment.id}/shared-links")

      assert %{"error" => "Not enough permissions to get related shared links"} ==
               json_response(conn, 403)
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
