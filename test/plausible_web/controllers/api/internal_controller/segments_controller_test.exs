defmodule PlausibleWeb.Api.Internal.SegmentsControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Repo

  describe "GET /internal-api/:domain/segments" do
    setup [:create_user, :create_new_site, :log_in]

    test "returns empty list when no segments", %{conn: conn, site: site} do
      conn =
        get(conn, "/internal-api/#{site.domain}/segments")

      assert json_response(conn, 200) == []
    end

    for role <- [:viewer, :owner] do
      test "returns list with personal and site segments for #{role}", %{conn: conn, user: user} do
        other_site = insert(:site, owner: user)
        other_user = insert(:user)

        site =
          insert(:site,
            memberships: [
              build(:site_membership, user: user, role: unquote(role)),
              build(:site_membership, user: other_user, role: :admin)
            ]
          )

        insert_list(2, :segment,
          site: other_site,
          owner_id: user.id,
          personal: false,
          name: "other site segment"
        )

        insert_list(10, :segment,
          site: site,
          owner_id: other_user.id,
          personal: true,
          name: "other user personal segment"
        )

        inserted_at = "2024-10-04T12:00:00"

        personal_segment =
          insert(:segment,
            site: site,
            owner_id: user.id,
            personal: true,
            name: "a personal segment",
            inserted_at: inserted_at,
            updated_at: inserted_at
          )

        emea_site_segment =
          insert(:segment,
            site: site,
            owner_id: other_user.id,
            personal: false,
            name: "EMEA region",
            inserted_at: inserted_at,
            updated_at: inserted_at
          )

        apac_site_segment =
          insert(:segment,
            site: site,
            owner_id: user.id,
            personal: false,
            name: "APAC region",
            inserted_at: inserted_at,
            updated_at: inserted_at
          )

        conn =
          get(conn, "/internal-api/#{site.domain}/segments")

        assert json_response(conn, 200) ==
                 Enum.map([apac_site_segment, personal_segment, emea_site_segment], fn s ->
                   %{
                     "id" => s.id,
                     "name" => s.name,
                     "personal" => s.personal,
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
    setup [:create_user, :create_new_site, :log_in]

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
      other_site = insert(:site, owner: user)

      %{id: segment_id} =
        insert(:segment,
          site: other_site,
          owner_id: user.id,
          personal: false,
          name: "any"
        )

      conn =
        get(conn, "/internal-api/#{site.domain}/segments/#{segment_id}")

      assert json_response(conn, 404) == %{
               "error" => "Segment not found with ID \"#{segment_id}\""
             }
    end

    test "serves 404 when user is not the segment owner and segment is personal",
         %{
           conn: conn,
           site: site
         } do
      other_user = insert(:user)

      inserted_at = "2024-10-01T10:00:00"
      updated_at = inserted_at

      %{
        id: segment_id
      } =
        insert(:segment,
          personal: true,
          owner_id: other_user.id,
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
      other_user = insert(:user)

      inserted_at = "2024-10-01T10:00:00"
      updated_at = inserted_at

      %{
        id: segment_id,
        segment_data: segment_data
      } =
        insert(:segment,
          personal: false,
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
               "personal" => false,
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
          personal: true,
          inserted_at: inserted_at,
          updated_at: updated_at
        )

      conn =
        get(conn, "/internal-api/#{site.domain}/segments/#{segment_id}")

      assert json_response(conn, 200) == %{
               "id" => segment_id,
               "owner_id" => user.id,
               "name" => "any",
               "personal" => true,
               "segment_data" => segment_data,
               "inserted_at" => inserted_at,
               "updated_at" => updated_at
             }
    end
  end

  describe "POST /internal-api/:domain/segments" do
    setup [:create_user, :create_new_site, :log_in]

    test "forbids viewers from creating site segments", %{conn: conn, user: user} do
      site =
        insert(:site, memberships: [build(:site_membership, user: user, role: :viewer)])

      conn =
        post(conn, "/internal-api/#{site.domain}/segments", %{
          "personal" => "false",
          "segment_data" => %{"filters" => [["is", "visit:entry_page", ["/blog"]]]},
          "name" => "any name"
        })

      assert json_response(conn, 403) == %{
               "error" => "Not enough permissions to create site segments"
             }
    end

    for %{role: role, personal: personal} <- [
          %{role: :viewer, personal: true},
          %{role: :admin, personal: true},
          %{role: :admin, personal: false}
        ] do
      test "#{role} can create segment with personal \"#{personal}\" successfully",
           %{conn: conn, user: user} do
        site =
          insert(:site, memberships: [build(:site_membership, user: user, role: unquote(role))])

        name = "any name"

        conn =
          post(conn, "/internal-api/#{site.domain}/segments", %{
            "personal" => unquote(personal),
            "segment_data" => %{"filters" => [["is", "visit:entry_page", ["/blog"]]]},
            "name" => name
          })

        response = json_response(conn, 200)

        assert %{
                 "name" => ^name,
                 "segment_data" => %{"filters" => [["is", "visit:entry_page", ["/blog"]]]},
                 "personal" => unquote(personal)
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
    setup [:create_user, :create_new_site, :log_in]

    for {current_personal, patch_personal} <- [
          {true, false},
          {false, true},
          {true, -1},
          {true, 0}
        ] do
      test "prevents viewers from updating segments with current personal value #{current_personal} with #{patch_personal}",
           %{
             conn: conn,
             user: user
           } do
        site = insert(:site, memberships: [build(:site_membership, user: user, role: :viewer)])
        inserted_at = "2024-09-01T10:00:00"
        updated_at = inserted_at

        %{id: segment_id} =
          insert(:segment,
            site: site,
            name: "foo",
            personal: unquote(current_personal),
            owner_id: user.id,
            inserted_at: inserted_at,
            updated_at: updated_at
          )

        conn =
          patch(conn, "/internal-api/#{site.domain}/segments/#{segment_id}", %{
            "name" => "updated name",
            "personal" => unquote(patch_personal)
          })

        assert json_response(conn, 403) == %{
                 "error" => "Not enough permissions to set segment visibility"
               }
      end
    end

    test "updates segment successfully", %{conn: conn, user: user} do
      site = insert(:site, memberships: [build(:site_membership, user: user, role: :admin)])

      name = "foo"
      inserted_at = "2024-09-01T10:00:00"
      updated_at = inserted_at
      personal = false

      %{id: segment_id, owner_id: owner_id, segment_data: segment_data} =
        insert(:segment,
          site: site,
          name: name,
          personal: personal,
          owner_id: user.id,
          inserted_at: inserted_at,
          updated_at: updated_at
        )

      conn =
        patch(conn, "/internal-api/#{site.domain}/segments/#{segment_id}", %{
          "name" => "updated name",
          "personal" => !personal
        })

      response = json_response(conn, 200)

      assert %{
               "owner_id" => ^owner_id,
               "inserted_at" => ^inserted_at,
               "id" => ^segment_id,
               "segment_data" => ^segment_data
             } = response

      assert response["name"] == "updated name"
      assert response["personal"] == !personal
      assert response["updated_at"] != inserted_at
    end
  end

  describe "DELETE /internal-api/:domain/segments/:segment_id" do
    setup [:create_user, :create_new_site, :log_in]

    test "forbids viewers from deleting site segments", %{conn: conn, user: user} do
      site = insert(:site, memberships: [build(:site_membership, user: user, role: :viewer)])

      %{id: segment_id} =
        insert(:segment,
          site: site,
          name: "any",
          personal: false,
          owner_id: user.id
        )

      conn =
        delete(conn, "/internal-api/#{site.domain}/segments/#{segment_id}")

      assert json_response(conn, 403) == %{
               "error" => "Not enough permissions to delete site segments"
             }
    end

    for %{role: role, personal: personal} <- [
          %{role: :viewer, personal: true},
          %{role: :admin, personal: true},
          %{role: :admin, personal: false}
        ] do
      test "#{role} can delete segment with personal \"#{personal}\" successfully",
           %{conn: conn, user: user} do
        site =
          insert(:site, memberships: [build(:site_membership, user: user, role: unquote(role))])

        user_id = user.id

        %{id: segment_id, segment_data: segment_data} =
          insert(:segment,
            site: site,
            name: "any",
            personal: unquote(personal),
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
                 "personal" => unquote(personal)
               } = response
      end
    end
  end
end
