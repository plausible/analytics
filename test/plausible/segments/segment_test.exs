defmodule Plausible.Segments.SegmentTest do
  use ExUnit.Case, async: true
  doctest Plausible.Segments.Segment, import: true

  setup do
    segment = %Plausible.Segments.Segment{
      name: "any name",
      type: :personal,
      segment_data: %{"filters" => ["is", "visit:page", ["/blog"]]},
      owner_id: 1,
      site_id: 100
    }

    {:ok, segment: segment}
  end

  test "changeset has required fields" do
    assert Plausible.Segments.Segment.changeset(%Plausible.Segments.Segment{}, %{}).errors == [
             segment_data: {"property \"filters\" must be an array with at least one member", []},
             name: {"can't be blank", [validation: :required]},
             segment_data: {"can't be blank", [validation: :required]},
             site_id: {"can't be blank", [validation: :required]},
             type: {"can't be blank", [validation: :required]},
             owner_id: {"can't be blank", [validation: :required]}
           ]
  end

  test "changeset does not allow setting owner_id to nil (setting to nil happens with database triggers)",
       %{segment: valid_segment} do
    assert Plausible.Segments.Segment.changeset(
             valid_segment,
             %{
               owner_id: nil
             }
           ).errors == [
             owner_id: {"can't be blank", [validation: :required]}
           ]
  end

  test "changeset forbids too long name", %{segment: valid_segment} do
    assert Plausible.Segments.Segment.changeset(
             valid_segment,
             %{
               name: String.duplicate("a", 256)
             }
           ).errors == [
             name:
               {"should be at most %{count} byte(s)",
                [{:count, 255}, {:validation, :length}, {:kind, :max}, {:type, :binary}]}
           ]
  end

  test "changeset forbids too large segment_data", %{segment: valid_segment} do
    assert Plausible.Segments.Segment.changeset(
             valid_segment,
             %{
               segment_data:
                 Jason.decode!(
                   ~s({"filters": ["is", "visit:exit_page", [#{Enum.map_join(1..(5 * 1024), ",", fn i -> "#{i}" end)}]]})
                 )
             }
           ).errors == [
             segment_data: {"should be at most %{count} byte(s)", [{:count, 5120}]}
           ]
  end

  test "changeset allows setting nil owner_id to a user id (to be able to recover dangling site segments)",
       %{segment: valid_segment} do
    assert Plausible.Segments.Segment.changeset(
             %Plausible.Segments.Segment{
               valid_segment
               | owner_id: nil
             },
             %{
               owner_id: 100_100
             }
           ).valid? == true
  end

  test "changeset requires segment_data to be structured as expected", %{segment: valid_segment} do
    assert Plausible.Segments.Segment.changeset(
             valid_segment,
             %{
               segment_data: %{"filters" => 1, "labels" => true, "other" => []}
             }
           ).errors == [
             {:segment_data, {"property \"labels\" must be map or nil", []}},
             {:segment_data,
              {"property \"filters\" must be an array with at least one member", []}},
             {:segment_data,
              {"must not contain any other property except \"filters\" and \"labels\"", []}}
           ]
  end

  test "changeset forbids empty filters list", %{segment: valid_segment} do
    assert Plausible.Segments.Segment.changeset(
             valid_segment,
             %{
               segment_data: %{
                 "filters" => []
               }
             }
           ).errors == [
             {:segment_data,
              {"property \"filters\" must be an array with at least one member", []}}
           ]
  end

  test "changeset permits well-structured segment data", %{segment: valid_segment} do
    assert Plausible.Segments.Segment.changeset(
             valid_segment,
             %{
               segment_data: %{
                 "filters" => [["is", "visit:country", ["DE"]]],
                 "labels" => %{"DE" => "Germany"}
               }
             }
           ).valid? == true
  end
end
