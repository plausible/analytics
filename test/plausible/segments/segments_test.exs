defmodule Plausible.SegmentsTest do
  use ExUnit.Case
  use Plausible.DataCase, async: true
  doctest Plausible.Segments, import: true
  alias Plausible.Segments.Segment

  setup [:create_user, :create_site]

  describe("searching segments by name") do
    for input <- [nil, "", " ", "\n", " \t"] do
      test "empty search input #{inspect(input)} yields site segments ordered by updated_at",
           %{
             site: site
           } do
        other_site = new_site()

        segment_scandinavia =
          insert(:segment,
            name: "Scandinavia",
            site: site,
            type: :site,
            updated_at: "2025-12-01T12:00:00"
          )

        segment_apac =
          insert(:segment,
            name: "APAC",
            site: site,
            type: :site,
            updated_at: "2025-12-01T10:00:00"
          )

        _segment_other_site = insert(:segment, name: "any", site: other_site, type: :site)
        _segment_personal = insert(:segment, name: "My segment", site: site, type: :personal)

        assert {:ok,
                [
                  list_all_result(segment_scandinavia),
                  list_all_result(segment_apac)
                ]} ==
                 Plausible.Segments.search_by_name(site, unquote(input))
      end
    end

    for input <- ["", "emea"] do
      test "search input #{inspect(input)} returns a maximum of 20 segments", %{site: site} do
        insert_list(100, :segment,
          name: "EMEA",
          site: site,
          type: :site
        )

        assert {:ok, segments} = Plausible.Segments.search_by_name(site, unquote(input))

        assert 20 == length(segments)
      end
    end

    test "search input \"A\" yields correctly ranked segments", %{
      site: site
    } do
      segment_scandinavia =
        insert(:segment,
          name: "Scandinavia",
          site: site,
          type: :site,
          updated_at: "2025-12-01T12:00:00"
        )

      segment_scandinavia_latest =
        insert(:segment,
          name: segment_scandinavia.name,
          site: site,
          type: :site,
          updated_at: "2025-12-01T13:00:00"
        )

      segment_scandinavia_longer_name =
        insert(:segment,
          name: "#{segment_scandinavia.name} (but longer)",
          site: site,
          type: :site,
          updated_at: "2025-12-01T12:00:00"
        )

      segment_a =
        insert(:segment,
          name: "A",
          site: site,
          type: :site,
          updated_at: "2025-12-01T10:00:00"
        )

      segment_apac =
        insert(:segment,
          name: "APAC",
          site: site,
          type: :site,
          updated_at: "2025-12-01T10:00:00"
        )

      segment_apac_copy =
        insert(:segment,
          name: "Copy of APAC",
          site: site,
          type: :site,
          updated_at: "2025-12-01T10:00:00"
        )

      _segment_personal = insert(:segment, name: "My segment", site: site, type: :personal)

      assert_matches {:ok,
                      [
                        # ranked here because it exactly matches input
                        %{
                          name: ^segment_a.name,
                          id: ^segment_a.id
                        },
                        # ranked here because it starts with the input
                        %{
                          name: ^segment_apac.name,
                          id: ^segment_apac.id
                        },
                        # ranked here because it has a substring starting with a space and the input
                        %{
                          name: ^segment_apac_copy.name,
                          id: ^segment_apac_copy.id
                        },
                        # ranked over next one (that has the same name) because it's been updated more lately
                        %{
                          name: ^segment_scandinavia_latest.name,
                          id: ^segment_scandinavia_latest.id
                        },
                        # ranked over next one because it has a shorter name
                        %{
                          name: ^segment_scandinavia.name,
                          id: ^segment_scandinavia.id
                        },
                        %{
                          name: ^segment_scandinavia_longer_name.name,
                          id: ^segment_scandinavia_longer_name.id
                        }
                      ]} =
                       Plausible.Segments.search_by_name(site, "A")
    end

    defp list_all_result(segment) do
      Plausible.Repo.load(Segment, %{
        name: segment.name,
        id: segment.id
      })
    end
  end

  describe "to_response_map/2" do
    test "returns owner name for segment with owner association loaded", %{user: user} do
      site = insert(:site, timezone: "Etc/UTC")

      segment =
        insert(:segment,
          name: "Segment with owner",
          type: :site,
          site: site,
          owner: user,
          inserted_at: ~N[2025-06-01 12:00:00],
          updated_at: ~N[2025-06-01 13:00:00]
        )

      assert_matches ^strict_map(%{
                       id: ^segment.id,
                       name: ^segment.name,
                       type: ^segment.type,
                       segment_data: ^segment.segment_data,
                       owner_id: ^user.id,
                       owner_name: ^user.name,
                       inserted_at: ~N[2025-06-01 12:00:00],
                       updated_at: ~N[2025-06-01 13:00:00]
                     }) = Plausible.Segments.to_response_map(segment, site)
    end

    test "returns nil owner_name when owner association is not loaded", %{user: user} do
      site = insert(:site, timezone: "Etc/UTC")

      segment =
        insert(:segment,
          name: "Segment with owner",
          site: site,
          type: :site,
          owner: user,
          inserted_at: ~N[2025-06-01 12:00:00],
          updated_at: ~N[2025-06-01 13:00:00]
        )
        |> Map.put(:owner, %Ecto.Association.NotLoaded{})

      assert_matches ^strict_map(%{
                       id: ^segment.id,
                       name: ^segment.name,
                       type: ^segment.type,
                       segment_data: ^segment.segment_data,
                       owner_id: ^user.id,
                       owner_name: nil,
                       inserted_at: ~N[2025-06-01 12:00:00],
                       updated_at: ~N[2025-06-01 13:00:00]
                     }) = Plausible.Segments.to_response_map(segment, site)
    end

    test "returns nil owner_name when owner_id is nil" do
      site = insert(:site, timezone: "Etc/UTC")

      segment =
        insert(:segment,
          name: "Orphaned segment",
          site: site,
          type: :site,
          owner: nil,
          inserted_at: ~N[2025-06-01 12:00:00],
          updated_at: ~N[2025-06-01 13:00:00]
        )

      assert_matches ^strict_map(%{
                       id: ^segment.id,
                       name: ^segment.name,
                       type: ^segment.type,
                       segment_data: ^segment.segment_data,
                       owner_id: nil,
                       owner_name: nil,
                       inserted_at: ~N[2025-06-01 12:00:00],
                       updated_at: ~N[2025-06-01 13:00:00]
                     }) = Plausible.Segments.to_response_map(segment, site)
    end

    test "shifts timestamps to site timezone" do
      site = insert(:site, timezone: "Europe/Tallinn")

      segment =
        insert(:segment,
          name: "My Segment",
          site: site,
          type: :site,
          owner: nil,
          inserted_at: ~N[2025-01-15 15:00:00],
          updated_at: ~N[2025-01-15 23:00:00]
        )

      assert_matches ^strict_map(%{
                       id: ^segment.id,
                       name: ^segment.name,
                       type: ^segment.type,
                       segment_data: ^segment.segment_data,
                       owner_id: nil,
                       owner_name: nil,
                       inserted_at: ~N[2025-01-15 17:00:00],
                       updated_at: ~N[2025-01-16 01:00:00]
                     }) = Plausible.Segments.to_response_map(segment, site)
    end
  end
end
