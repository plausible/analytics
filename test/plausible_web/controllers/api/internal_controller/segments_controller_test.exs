defmodule PlausibleWeb.Api.Internal.SegmentsControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Repo
  use Plausible.Teams.Test

  describe "GET /internal-api/:domain/segments with permissions overrides" do
    setup [:create_user, :log_in, :create_site]

    # adds unselectable segments to database
    setup %{user: user, site: site} = input do
      other_user = new_user()
      other_site = new_site(owner: other_user, team: team_of(user))

      insert_list(2, :segment,
        site: other_site,
        owner: user,
        type: :site,
        name: "site segment on another site"
      )

      insert_list(2, :segment,
        site: other_site,
        owner: user,
        type: :personal,
        name: "personal segment on another site"
      )

      insert_list(10, :segment,
        site: site,
        owner: other_user,
        type: :personal,
        name: "other user personal segment on same site"
      )

      {:ok, input}
    end

    test "respects [] permissions", %{conn: conn, site: site} do
      conn =
        get(
          conn |> put_private(:test_override_permissions, []),
          "/internal-api/#{site.domain}/segments"
        )

      assert json_response(conn, 403) == %{"error" => "Not enough permissions to get segments"}
    end

    test "handles [:can_list_personal_segments] permissions", %{
      conn: conn,
      site: site,
      user: user
    } do
      inserted_at = "2024-10-04T12:00:00"

      _site_segments =
        insert_list(2, :segment,
          site: site,
          owner: user,
          type: :site,
          name: "any site segment",
          inserted_at: inserted_at,
          updated_at: inserted_at
        )

      personal_segments =
        insert_list(4, :segment,
          site: site,
          owner: user,
          type: :personal,
          name: "any personal segment",
          inserted_at: inserted_at,
          updated_at: inserted_at
        )

      conn =
        get(
          conn
          |> put_private(:test_override_permissions, [:can_list_personal_segments]),
          "/internal-api/#{site.domain}/segments"
        )

      assert json_response(conn, 200) ==
               Enum.reverse(
                 Enum.map(personal_segments, fn s ->
                   %{
                     "id" => s.id,
                     "name" => s.name,
                     "type" => Atom.to_string(s.type),
                     "owner_id" => user.id,
                     "inserted_at" => inserted_at,
                     "updated_at" => inserted_at,
                     "segment_data" => nil
                   }
                 end)
               )
    end

    test "handles [:can_list_site_segments, :can_list_personal_segments] permissions", %{
      conn: conn,
      site: site,
      user: user
    } do
      inserted_at = "2024-10-04T12:00:00"

      site_segments =
        insert_list(2, :segment,
          site: site,
          owner: user,
          type: :site,
          name: "any site segment",
          inserted_at: inserted_at,
          updated_at: inserted_at
        )

      personal_segments =
        insert_list(4, :segment,
          site: site,
          owner: user,
          type: :personal,
          name: "any personal segment",
          inserted_at: inserted_at,
          updated_at: inserted_at
        )

      conn =
        get(
          conn
          |> put_private(:test_override_permissions, [
            :can_list_personal_segments,
            :can_list_site_segments
          ]),
          "/internal-api/#{site.domain}/segments"
        )

      assert json_response(conn, 200) ==
               Enum.map(Enum.reverse(personal_segments) ++ Enum.reverse(site_segments), fn s ->
                 %{
                   "id" => s.id,
                   "name" => s.name,
                   "type" => Atom.to_string(s.type),
                   "owner_id" => user.id,
                   "inserted_at" => inserted_at,
                   "updated_at" => inserted_at,
                   "segment_data" => nil
                 }
               end)
    end

    test "handles [:can_list_site_segments] permissions", %{
      conn: conn,
      site: site,
      user: user
    } do
      inserted_at = "2024-10-04T12:00:00"

      site_segments =
        insert_list(2, :segment,
          site: site,
          owner: user,
          type: :site,
          name: "any site segment",
          inserted_at: inserted_at,
          updated_at: inserted_at
        )

      _personal_segments =
        insert_list(4, :segment,
          site: site,
          owner: user,
          type: :personal,
          name: "any personal segment",
          inserted_at: inserted_at,
          updated_at: inserted_at
        )

      conn =
        get(
          conn
          |> put_private(:test_override_permissions, [
            :can_list_site_segments
          ]),
          "/internal-api/#{site.domain}/segments"
        )

      assert json_response(conn, 200) ==
               Enum.map(Enum.reverse(site_segments), fn s ->
                 %{
                   "id" => s.id,
                   "name" => s.name,
                   "type" => Atom.to_string(s.type),
                   "owner_id" => nil,
                   "inserted_at" => inserted_at,
                   "updated_at" => inserted_at,
                   "segment_data" => nil
                 }
               end)
    end
  end

  describe "GET /internal-api/:domain/segments" do
    setup [:create_user, :log_in, :create_site]

    test "returns empty list when no segments", %{conn: conn, site: site} do
      conn =
        get(conn, "/internal-api/#{site.domain}/segments")

      assert json_response(conn, 200) == []
    end

    test "returns site segments list when looking at a public dashboard", %{conn: conn} do
      other_user = new_user()
      site = new_site(owner: other_user, public: true)
      inserted_at = "2024-10-04T12:00:00"

      site_segments =
        insert_list(2, :segment,
          site: site,
          owner: other_user,
          type: :site,
          name: "other site segment",
          inserted_at: inserted_at,
          updated_at: inserted_at
        )

      insert_list(10, :segment,
        site: site,
        owner: other_user,
        type: :personal,
        name: "other user personal segment"
      )

      conn = get(conn, "/internal-api/#{site.domain}/segments")

      assert json_response(conn, 200) ==
               Enum.reverse(
                 Enum.map(site_segments, fn s ->
                   %{
                     "id" => s.id,
                     "name" => s.name,
                     "type" => Atom.to_string(s.type),
                     "owner_id" => nil,
                     "inserted_at" => inserted_at,
                     "updated_at" => inserted_at,
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
        get(conn, "/internal-api/#{site.domain}/segments")

      assert json_response(conn, 200) == []
    end

    for role <- [:viewer, :owner] do
      test "returns list with personal and site segments for #{role}, avoiding segments from other site",
           %{conn: conn, user: user, site: site} do
        other_user = new_user()
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

        inserted_at = "2024-10-04T12:00:00"

        personal_segment =
          insert(:segment,
            site: site,
            owner: user,
            type: :personal,
            name: "a personal segment",
            inserted_at: inserted_at,
            updated_at: inserted_at
          )

        emea_site_segment =
          insert(:segment,
            site: site,
            owner: other_user,
            type: :site,
            name: "EMEA region",
            inserted_at: inserted_at,
            updated_at: inserted_at
          )

        apac_site_segment =
          insert(:segment,
            site: site,
            owner: user,
            type: :site,
            name: "APAC region",
            inserted_at: inserted_at,
            updated_at: inserted_at
          )

        conn =
          get(conn, "/internal-api/#{site.domain}/segments")

        assert json_response(conn, 200) ==
                 Enum.map([apac_site_segment, emea_site_segment, personal_segment], fn s ->
                   %{
                     "id" => s.id,
                     "name" => s.name,
                     "type" => Atom.to_string(s.type),
                     "owner_id" => s.owner_id,
                     "inserted_at" => inserted_at,
                     "updated_at" => inserted_at,
                     "segment_data" => nil
                   }
                 end)
      end
    end
  end

  describe "GET /internal-api/:domain/segments/:segment_id" do
    setup [:create_user, :create_site, :log_in]

    test "serves 404 when invalid segment key used", %{conn: conn, site: site} do
      conn =
        get(conn, "/internal-api/#{site.domain}/segments/any-id")

      assert json_response(conn, 404) == %{"error" => "Segment not found with ID \"any-id\""}
    end

    test "serves 404 when no segment found", %{conn: conn, site: site} do
      conn =
        get(conn, "/internal-api/#{site.domain}/segments/100100")

      assert json_response(conn, 404) == %{"error" => "Segment not found with ID \"100100\""}
    end

    test "serves 404 when segment is for another site", %{conn: conn, site: site, user: user} do
      other_site = new_site(owner: user)

      %{id: segment_id} =
        insert(:segment,
          site: other_site,
          owner: user,
          type: :site,
          name: "any"
        )

      conn =
        get(conn, "/internal-api/#{site.domain}/segments/#{segment_id}")

      assert json_response(conn, 404) == %{
               "error" => "Segment not found with ID \"#{segment_id}\""
             }
    end

    test "serves 404 for viewing contents of site segments for viewers of public dashboards",
         %{
           conn: conn
         } do
      site = new_site(public: true)
      other_user = add_guest(site, user: new_user(), role: :editor)

      inserted_at = "2024-10-01T10:00:00"
      updated_at = inserted_at

      %{
        id: segment_id
      } =
        insert(:segment,
          type: :site,
          owner: other_user,
          site: site,
          name: "any",
          inserted_at: inserted_at,
          updated_at: updated_at
        )

      conn =
        get(conn, "/internal-api/#{site.domain}/segments/#{segment_id}")

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

      inserted_at = "2024-10-01T10:00:00"
      updated_at = inserted_at

      %{
        id: segment_id
      } =
        insert(:segment,
          type: :personal,
          owner: other_user,
          site: site,
          name: "any",
          inserted_at: inserted_at,
          updated_at: updated_at
        )

      conn =
        get(conn, "/internal-api/#{site.domain}/segments/#{segment_id}")

      assert json_response(conn, 404) == %{
               "error" => "Segment not found with ID \"#{segment_id}\""
             }
    end

    test "serves 200 with segment when user is not the segment owner and segment is not personal",
         %{
           conn: conn,
           site: site
         } do
      other_user = add_guest(site, role: :editor)

      inserted_at = "2024-10-01T10:00:00"
      updated_at = inserted_at

      %{
        id: segment_id,
        segment_data: segment_data
      } =
        insert(:segment,
          type: :site,
          owner_id: other_user.id,
          site: site,
          name: "any",
          inserted_at: inserted_at,
          updated_at: updated_at
        )

      conn =
        get(conn, "/internal-api/#{site.domain}/segments/#{segment_id}")

      assert json_response(conn, 200) == %{
               "id" => segment_id,
               "owner_id" => other_user.id,
               "name" => "any",
               "type" => "site",
               "segment_data" => segment_data,
               "inserted_at" => inserted_at,
               "updated_at" => updated_at
             }
    end

    test "serves 200 with segment when user is segment owner", %{
      conn: conn,
      site: site,
      user: user
    } do
      inserted_at = "2024-09-01T10:00:00"
      updated_at = inserted_at

      %{id: segment_id, segment_data: segment_data} =
        insert(:segment,
          site: site,
          name: "any",
          owner_id: user.id,
          type: :personal,
          inserted_at: inserted_at,
          updated_at: updated_at
        )

      conn =
        get(conn, "/internal-api/#{site.domain}/segments/#{segment_id}")

      assert json_response(conn, 200) == %{
               "id" => segment_id,
               "owner_id" => user.id,
               "name" => "any",
               "type" => "personal",
               "segment_data" => segment_data,
               "inserted_at" => inserted_at,
               "updated_at" => updated_at
             }
    end
  end

  describe "POST /internal-api/:domain/segments" do
    setup [:create_user, :log_in, :create_site]

    test "forbids viewers from creating site segments", %{conn: conn, user: user} do
      site = new_site()
      add_guest(site, user: user, role: :viewer)

      conn =
        post(conn, "/internal-api/#{site.domain}/segments", %{
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
        post(conn, "/internal-api/#{site.domain}/segments", %{
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
        post(conn, "/internal-api/#{site.domain}/segments", %{
          "type" => "site",
          "segment_data" => %{
            "filters" => [["is", "entry_page", ["/blog"]]]
          },
          "name" => "any name"
        })

      assert json_response(conn, 400) == %{
               "errors" => ["#/filters/0: Invalid filter [\"is\", \"entry_page\", [\"/blog\"]]"]
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

        t = Atom.to_string(unquote(type))
        name = "any name"

        conn =
          post(conn, "/internal-api/#{site.domain}/segments", %{
            "type" => t,
            "segment_data" => %{"filters" => [["is", "visit:entry_page", ["/blog"]]]},
            "name" => name
          })

        response = json_response(conn, 200)

        assert %{
                 "name" => ^name,
                 "segment_data" => %{"filters" => [["is", "visit:entry_page", ["/blog"]]]},
                 "type" => ^t
               } = response

        %{
          "id" => id,
          "owner_id" => owner_id,
          "updated_at" => updated_at,
          "inserted_at" => inserted_at
        } =
          response

        assert is_integer(id)
        assert ^owner_id = user.id
        assert is_binary(inserted_at)
        assert is_binary(updated_at)
        assert ^inserted_at = updated_at
      end
    end
  end

  describe "PATCH /internal-api/:domain/segments/:segment_id" do
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

        inserted_at = "2024-09-01T10:00:00"
        updated_at = inserted_at

        %{id: segment_id} =
          insert(:segment,
            site: site,
            name: "foo",
            type: unquote(current_type),
            owner_id: user.id,
            inserted_at: inserted_at,
            updated_at: updated_at
          )

        conn =
          patch(conn, "/internal-api/#{site.domain}/segments/#{segment_id}", %{
            "name" => "updated name",
            "type" => Atom.to_string(unquote(patch_type))
          })

        assert json_response(conn, 403) == %{
                 "error" => "Not enough permissions to edit segment"
               }
      end
    end

    for {filters, expected_errors} <- [
          {[["foo", "bar"]], ["#/filters/0: Invalid filter [\"foo\", \"bar\"]"]}
          # {[["not", ["is", "visit:entry_page", ["/campaigns/:campaign_name"]]]], "..."}
        ] do
      test "prevents owners from updating segments to invalid filters #{inspect(filters)} with error 400",
           %{
             conn: conn,
             user: user,
             site: site
           } do
        inserted_at = "2024-09-01T10:00:00"
        updated_at = inserted_at

        %{id: segment_id} =
          insert(:segment,
            site: site,
            name: "any name",
            type: :personal,
            owner_id: user.id,
            inserted_at: inserted_at,
            updated_at: updated_at
          )

        conn =
          patch(conn, "/internal-api/#{site.domain}/segments/#{segment_id}", %{
            "segment_data" => %{"filters" => unquote(filters)}
          })

        assert json_response(conn, 400) == %{
                 "errors" => unquote(expected_errors)
               }
      end
    end

    test "editors can update a segment", %{conn: conn, user: user} do
      site = new_site()
      add_guest(site, user: user, role: :editor)

      name = "foo"
      inserted_at = "2024-09-01T10:00:00"
      updated_at = inserted_at
      type = :site
      updated_type = :personal

      %{id: segment_id, owner_id: owner_id, segment_data: segment_data} =
        insert(:segment,
          site: site,
          name: name,
          type: type,
          owner_id: user.id,
          inserted_at: inserted_at,
          updated_at: updated_at
        )

      conn =
        patch(conn, "/internal-api/#{site.domain}/segments/#{segment_id}", %{
          "name" => "updated name",
          "type" => updated_type
        })

      response = json_response(conn, 200)

      assert %{
               "owner_id" => ^owner_id,
               "inserted_at" => ^inserted_at,
               "id" => ^segment_id,
               "segment_data" => ^segment_data
             } = response

      assert response["name"] == "updated name"
      assert response["type"] == Atom.to_string(updated_type)
      assert response["updated_at"] != inserted_at
    end
  end

  describe "DELETE /internal-api/:domain/segments/:segment_id" do
    setup [:create_user, :create_site, :log_in]

    test "forbids viewers from deleting site segments", %{conn: conn, user: user} do
      site = new_site()
      add_guest(site, user: user, role: :viewer)

      %{id: segment_id} =
        insert(:segment,
          site: site,
          name: "any",
          type: :site,
          owner_id: user.id
        )

      conn =
        delete(conn, "/internal-api/#{site.domain}/segments/#{segment_id}")

      assert json_response(conn, 403) == %{
               "error" => "Not enough permissions to delete segment"
             }
    end

    for %{role: role, type: type} <- [
          %{role: :viewer, type: :personal},
          %{role: :editor, type: :personal},
          %{role: :editor, type: :site}
        ] do
      test "#{role} can delete segment with type \"#{type}\" successfully",
           %{conn: conn, user: user} do
        site = new_site()
        add_guest(site, user: user, role: unquote(role))

        t = Atom.to_string(unquote(type))

        user_id = user.id

        %{id: segment_id, segment_data: segment_data} =
          insert(:segment,
            site: site,
            name: "any",
            type: t,
            owner_id: user_id
          )

        conn =
          delete(conn, "/internal-api/#{site.domain}/segments/#{segment_id}")

        response = json_response(conn, 200)

        assert %{
                 "id" => ^segment_id,
                 "owner_id" => ^user_id,
                 "name" => "any",
                 "segment_data" => ^segment_data,
                 "type" => ^t
               } = response
      end
    end
  end
end
