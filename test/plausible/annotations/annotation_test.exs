defmodule Plausible.Annotations.AnnotationTest do
  use ExUnit.Case, async: true
  alias Plausible.Annotations.Annotation

  describe "changeset/3 for date granularity" do
    for {dt, expected_errors} <- [
          {"2026-06-30T00:00:00", [date: {"must be supplied for chosen granularity", []}]},
          {"2026-06-30T00:00:00Z", [date: {"must be supplied for chosen granularity", []}]},
          {~U[2026-06-30 14:30:00Z], [date: {"must be supplied for chosen granularity", []}]},
          {"2026-07-05", [datetime: {"is invalid", [type: :utc_datetime, validation: :cast]}]},
          {~D[2026-07-06], [datetime: {"is invalid", [type: :utc_datetime, validation: :cast]}]}
        ] do
      test "rejects datetime #{dt} with appropriate error" do
        changeset =
          Annotation.changeset(
            %Annotation{},
            %{
              note: "feature released",
              type: "personal",
              granularity: "date",
              datetime: unquote(Macro.escape(dt))
            },
            "Etc/UTC"
          )

        assert changeset.errors == unquote(Macro.escape(expected_errors))
      end
    end

    test "rejects invalid date value" do
      changeset =
        Annotation.changeset(
          %Annotation{},
          %{
            note: "feature released",
            type: "personal",
            granularity: "date",
            date: "2026-13-45"
          },
          "Etc/UTC"
        )

      assert [date: {"is invalid", _}] = changeset.errors
    end

    for {d, expected} <- [
          {"2026-06-30", ~U[2026-06-30 00:00:00Z]},
          {~D[2026-07-01], ~U[2026-07-01 00:00:00Z]}
        ] do
      test "accepts date #{d}, parsing it to that date at UTC midnight (#{expected})" do
        changeset =
          Annotation.changeset(
            %Annotation{},
            %{
              note: "feature released",
              type: "personal",
              granularity: "date",
              date: unquote(Macro.escape(d))
            },
            Enum.random(Plausible.Timezones.zone_list())
          )

        assert changeset.valid?
        assert changeset.changes.datetime == unquote(Macro.escape(expected))
      end
    end
  end

  describe "changeset/3 for minute granularity" do
    for d <- ["2026-07-05", ~D[2026-07-06]] do
      test "requires :datetime to be present, given date: #{d}" do
        changeset =
          Annotation.changeset(
            %Annotation{},
            %{
              note: "feature released",
              type: "personal",
              granularity: "minute",
              date: unquote(Macro.escape(d))
            },
            "Etc/UTC"
          )

        assert changeset.errors == [datetime: {"must be supplied for chosen granularity", []}]
      end
    end

    for dt <- ["2026-06-30", ~D[2026-07-01], "invalid"] do
      test "rejects invalid :datetime, given #{dt}" do
        changeset =
          Annotation.changeset(
            %Annotation{},
            %{
              note: "feature released",
              type: "personal",
              granularity: "minute",
              datetime: unquote(Macro.escape(dt))
            },
            "Etc/UTC"
          )

        assert [datetime: {"is invalid", _}] = changeset.errors
      end
    end

    for {dt, expected, tz} <- [
          {"2026-06-30T14:30:00Z", ~U[2026-06-30 14:30:00Z],
           Enum.random(Plausible.Timezones.zone_list())},
          {"2026-06-30T10:00:00-02:00", ~U[2026-06-30 12:00:00Z],
           Enum.random(Plausible.Timezones.zone_list())},
          {~U[2026-06-30 14:30:00Z], ~U[2026-06-30 14:30:00Z],
           Enum.random(Plausible.Timezones.zone_list())},
          {"2026-06-30T14:30:00", ~U[2026-06-30 14:30:00Z], "Etc/UTC"},
          {"2026-06-30T14:30:00", ~U[2026-06-30 11:30:00Z], "Europe/Tallinn"}
        ] do
      test "accepts :datetime #{dt} and parses it to #{expected} UTC point in time for the site with timezone #{tz}" do
        changeset =
          Annotation.changeset(
            %Annotation{},
            %{
              note: "feature released",
              type: "personal",
              granularity: "minute",
              datetime: unquote(Macro.escape(dt))
            },
            unquote(tz)
          )

        assert changeset.valid?
        assert changeset.changes.datetime == unquote(Macro.escape(expected))
      end
    end
  end

  describe "changeset/3 when both date and datetime are provided" do
    for granularity <- ["date", "minute"] do
      test "rejects both being set for #{granularity} granularity" do
        changeset =
          Annotation.changeset(
            %Annotation{},
            %{
              note: "feature released",
              type: "personal",
              granularity: unquote(granularity),
              date: "2026-06-30",
              datetime: "2026-06-30T14:30:00Z"
            },
            "Etc/UTC"
          )

        assert changeset.errors == [
                 granularity: {"expects either date or datetime to be set", []}
               ]
      end
    end
  end
end
