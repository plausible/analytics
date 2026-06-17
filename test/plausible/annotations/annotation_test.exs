defmodule Plausible.Annotations.AnnotationTest do
  use ExUnit.Case, async: true
  alias Plausible.Annotations.Annotation

  describe "date-granularity" do
    test "a full datetime string is rejected" do
      changeset =
        Annotation.changeset(%Annotation{}, %{
          "granularity" => "date",
          "datetime" => "2026-06-30T00:00:00Z"
        })

      assert {"is invalid for granularity", []} = changeset.errors[:datetime]
    end

    test "a non-midnight %DateTime{} is rejected" do
      changeset =
        Annotation.changeset(%Annotation{}, %{
          "granularity" => "date",
          "datetime" => ~U[2026-06-30 14:30:00Z]
        })

      assert {"is invalid for granularity", []} = changeset.errors[:datetime]
    end

    test "an unparseable date string is rejected" do
      changeset =
        Annotation.changeset(%Annotation{}, %{
          "granularity" => "date",
          "datetime" => "not-a-date"
        })

      assert {"is invalid for granularity", []} = changeset.errors[:datetime]
    end

    test "an invalid calendar date is rejected" do
      changeset =
        Annotation.changeset(%Annotation{}, %{
          "granularity" => "date",
          "datetime" => "2026-13-45"
        })

      assert {"is invalid for granularity", []} = changeset.errors[:datetime]
    end

    test "a bare YYYY-MM-DD string becomes UTC midnight" do
      changeset =
        Annotation.changeset(%Annotation{}, %{
          "note" => "feature released",
          "type" => "personal",
          "site_id" => 1,
          "owner_id" => 1,
          "granularity" => "date",
          "datetime" => "2026-06-30"
        })

      assert changeset.valid?
      assert changeset.changes.datetime == ~U[2026-06-30 00:00:00Z]
    end

    test "a %Date{} struct becomes UTC midnight" do
      changeset =
        Annotation.changeset(%Annotation{}, %{
          "note" => "feature released",
          "type" => "personal",
          "site_id" => 1,
          "owner_id" => 1,
          "granularity" => "date",
          "datetime" => ~D[2026-06-30]
        })

      assert changeset.valid?
      assert changeset.changes.datetime == ~U[2026-06-30 00:00:00Z]
    end
  end

  describe "minute-granularity" do
    test "a bare date string is rejected" do
      changeset =
        Annotation.changeset(%Annotation{}, %{
          "granularity" => "minute",
          "datetime" => "2026-06-30"
        })

      assert {"is invalid for granularity", []} = changeset.errors[:datetime]
    end

    test "an unparseable datetime is rejected" do
      changeset =
        Annotation.changeset(%Annotation{}, %{
          "granularity" => "minute",
          "datetime" => "garbage"
        })

      assert {"is invalid for granularity", []} = changeset.errors[:datetime]
    end

    test "a Z-suffixed datetime string is kept in UTC" do
      changeset =
        Annotation.changeset(%Annotation{}, %{
          "note" => "feature released",
          "type" => "personal",
          "site_id" => 1,
          "owner_id" => 1,
          "granularity" => "minute",
          "datetime" => "2026-06-30T14:30:00Z"
        })

      assert changeset.valid?
      assert changeset.changes.datetime == ~U[2026-06-30 14:30:00Z]
    end

    test "an offset datetime string is shifted to UTC" do
      changeset =
        Annotation.changeset(%Annotation{}, %{
          "note" => "feature released",
          "type" => "personal",
          "site_id" => 1,
          "owner_id" => 1,
          "granularity" => "minute",
          "datetime" => "2026-06-30T10:00:00-02:00"
        })

      assert changeset.valid?
      assert changeset.changes.datetime == ~U[2026-06-30 12:00:00Z]
    end

    test "a %DateTime{} is passed through in UTC" do
      changeset =
        Annotation.changeset(%Annotation{}, %{
          "note" => "feature released",
          "type" => "personal",
          "site_id" => 1,
          "owner_id" => 1,
          "granularity" => "minute",
          "datetime" => ~U[2026-06-30 14:30:00Z]
        })

      assert changeset.valid?
      assert changeset.changes.datetime == ~U[2026-06-30 14:30:00Z]
    end
  end

  describe "unknown granularity" do
    test "defers to Ecto's enum cast, not our coercion error" do
      changeset =
        Annotation.changeset(%Annotation{}, %{
          "granularity" => "hour",
          "datetime" => "2026-06-30T10:00:00Z"
        })

      assert changeset.errors[:granularity]
      refute changeset.errors[:datetime]
    end
  end

  describe "granularity change" do
    test "flipping :date to :minute without a datetime is rejected" do
      existing = %Annotation{granularity: :date, datetime: ~U[2026-06-15 00:00:00Z]}
      changeset = Annotation.changeset(existing, %{"granularity" => "minute"})

      assert {"must be supplied when granularity changes", []} = changeset.errors[:datetime]
    end

    test "flipping :minute to :date without a datetime is rejected" do
      existing = %Annotation{granularity: :minute, datetime: ~U[2026-06-15 14:30:00Z]}
      changeset = Annotation.changeset(existing, %{"granularity" => "date"})

      assert {"must be supplied when granularity changes", []} = changeset.errors[:datetime]
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
        Annotation.changeset(existing, %{
          "granularity" => "minute",
          "datetime" => "2026-06-15T14:30:00Z"
        })

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
        Annotation.changeset(existing, %{
          "granularity" => "date",
          "datetime" => "2026-06-16"
        })

      assert changeset.valid?
      assert changeset.changes.datetime == ~U[2026-06-16 00:00:00Z]
    end
  end
end
