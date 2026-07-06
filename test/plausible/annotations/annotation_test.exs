defmodule Plausible.Annotations.AnnotationTest do
  use ExUnit.Case, async: true
  alias Plausible.Annotations.Annotation

  describe "date-granularity" do
    test "a full datetime string is rejected" do
      changeset =
        Annotation.changeset(
          %Annotation{},
          %{
            "note" => "test",
            "type" => "personal",
            "granularity" => "date",
            "datetime" => "2026-06-30T00:00:00Z"
          },
          "Etc/UTC"
        )

      assert {"must be supplied for chosen granularity", []} = changeset.errors[:date]
    end

    test "a non-midnight %DateTime{} is rejected" do
      changeset =
        Annotation.changeset(
          %Annotation{},
          %{
            "note" => "test",
            "type" => "personal",
            "granularity" => "date",
            "datetime" => ~U[2026-06-30 14:30:00Z]
          },
          "Etc/UTC"
        )

      assert {"must be supplied for chosen granularity", []} = changeset.errors[:date]
    end

    test "an unparsable date string is rejected" do
      changeset =
        Annotation.changeset(
          %Annotation{},
          %{
            "granularity" => "date",
            "datetime" => "not-a-date"
          },
          "Etc/UTC"
        )

      assert {"is invalid", _} = changeset.errors[:datetime]
    end

    test "an invalid calendar date is rejected" do
      changeset =
        Annotation.changeset(
          %Annotation{},
          %{
            "granularity" => "date",
            "datetime" => "2026-13-45"
          },
          "Etc/UTC"
        )

      assert {"is invalid", _} = changeset.errors[:datetime]
    end

    test "a bare YYYY-MM-DD string becomes UTC midnight" do
      changeset =
        Annotation.changeset(
          %Annotation{},
          %{
            "note" => "feature released",
            "type" => "personal",
            "site_id" => 1,
            "owner_id" => 1,
            "granularity" => "date",
            "date" => "2026-06-30"
          },
          "Etc/UTC"
        )

      assert changeset.valid?
      assert changeset.changes.datetime == ~U[2026-06-30 00:00:00Z]
    end

    test "a %Date{} struct becomes UTC midnight" do
      changeset =
        Annotation.changeset(
          %Annotation{},
          %{
            "note" => "feature released",
            "type" => "personal",
            "site_id" => 1,
            "owner_id" => 1,
            "granularity" => "date",
            "date" => ~D[2026-06-30]
          },
          "Etc/UTC"
        )

      assert changeset.valid?
      assert changeset.changes.datetime == ~U[2026-06-30 00:00:00Z]
    end
  end

  describe "minute-granularity" do
    test "a bare date string is rejected" do
      changeset =
        Annotation.changeset(
          %Annotation{},
          %{
            "granularity" => "minute",
            "datetime" => "2026-06-30"
          },
          "Etc/UTC"
        )

      assert {"is invalid", _} = changeset.errors[:datetime]
    end

    test "an unparsable datetime is rejected" do
      changeset =
        Annotation.changeset(
          %Annotation{},
          %{
            "granularity" => "minute",
            "datetime" => "garbage"
          },
          "Etc/UTC"
        )

      assert {"is invalid", _} = changeset.errors[:datetime]
    end

    test "a Z-suffixed datetime string is kept in UTC" do
      changeset =
        Annotation.changeset(
          %Annotation{},
          %{
            "note" => "feature released",
            "type" => "personal",
            "site_id" => 1,
            "owner_id" => 1,
            "granularity" => "minute",
            "datetime" => "2026-06-30T14:30:00Z"
          },
          "Etc/UTC"
        )

      assert changeset.valid?
      assert changeset.changes.datetime == ~U[2026-06-30 14:30:00Z]
    end

    test "an offset datetime string is shifted to UTC" do
      changeset =
        Annotation.changeset(
          %Annotation{},
          %{
            "note" => "feature released",
            "type" => "personal",
            "site_id" => 1,
            "owner_id" => 1,
            "granularity" => "minute",
            "datetime" => "2026-06-30T10:00:00-02:00"
          },
          "Etc/UTC"
        )

      assert changeset.valid?
      assert changeset.changes.datetime == ~U[2026-06-30 12:00:00Z]
    end

    test "a %DateTime{} is passed through in UTC" do
      changeset =
        Annotation.changeset(
          %Annotation{},
          %{
            "note" => "feature released",
            "type" => "personal",
            "site_id" => 1,
            "owner_id" => 1,
            "granularity" => "minute",
            "datetime" => ~U[2026-06-30 14:30:00Z]
          },
          "Etc/UTC"
        )

      assert changeset.valid?
      assert changeset.changes.datetime == ~U[2026-06-30 14:30:00Z]
    end
  end

  describe "unknown granularity" do
    test "defers to Ecto's enum cast, not our coercion error" do
      changeset =
        Annotation.changeset(
          %Annotation{},
          %{
            "granularity" => "hour",
            "datetime" => "2026-06-30T10:00:00Z"
          },
          "Etc/UTC"
        )

      assert changeset.errors[:granularity]
      refute changeset.errors[:datetime]
    end
  end

  describe "granularity change" do
    test "flipping :date to :minute without a datetime is rejected" do
      existing = %Annotation{
        granularity: :date,
        datetime: ~U[2026-06-15 00:00:00Z],
        note: "test",
        type: :personal
      }

      changeset = Annotation.changeset(existing, %{"granularity" => "minute"}, "Etc/UTC")

      assert {"must be supplied for chosen granularity", []} = changeset.errors[:datetime]
    end

    test "flipping :minute to :date without a datetime is rejected" do
      existing = %Annotation{
        granularity: :minute,
        datetime: ~U[2026-06-15 14:30:00Z],
        note: "test",
        type: :personal
      }

      changeset = Annotation.changeset(existing, %{"granularity" => "date"}, "Etc/UTC")

      assert {"must be supplied for chosen granularity", []} = changeset.errors[:date]
    end

    test "flipping granularity to minute with an appropriate datetime is accepted" do
      existing = %Annotation{
        note: "feature released",
        type: :personal,
        site_id: 1,
        owner_id: 1,
        granularity: :date,
        datetime: ~U[2026-06-15 00:00:00Z]
      }

      changeset =
        Annotation.changeset(
          existing,
          %{
            "granularity" => "minute",
            "datetime" => "2026-06-15T14:30:00Z"
          },
          "Etc/UTC"
        )

      assert changeset.valid?
      assert changeset.changes.datetime == ~U[2026-06-15 14:30:00Z]
    end

    test "flipping granularity to date with an appropriate date is accepted" do
      existing = %Annotation{
        note: "feature released",
        type: :personal,
        site_id: 1,
        owner_id: 1,
        granularity: :minute,
        datetime: ~U[2026-06-15 10:00:00Z]
      }

      changeset =
        Annotation.changeset(
          existing,
          %{
            "granularity" => "date",
            "date" => "2026-06-16"
          },
          "Etc/UTC"
        )

      assert changeset.valid?
      assert changeset.changes.datetime == ~U[2026-06-16 00:00:00Z]
    end
  end
end
