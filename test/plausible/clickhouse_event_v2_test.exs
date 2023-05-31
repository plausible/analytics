defmodule Plausible.ClickhouseEventV2Test do
  use Plausible.DataCase

  describe "revenue_source_amount" do
    test "saves decimals as integers" do
      populate_stats([
        build(:event,
          name: "revenue-dump-as-int",
          revenue_source_amount: Decimal.new("123456.3213")
        )
      ])

      assert %{rows: [[dumped]]} =
               Ecto.Adapters.SQL.query!(
                 Plausible.ClickhouseRepo,
                 "SELECT revenue_source_amount FROM events_v2 WHERE name = 'revenue-dump-as-int'"
               )

      assert dumped == 123_456_321_300
    end

    test "uses the max uint64 value as missing value" do
      populate_stats([
        build(:event, name: "revenue-dump-as-max-int", revenue_source_amount: nil)
      ])

      assert %{rows: [[dumped]]} =
               Ecto.Adapters.SQL.query!(
                 Plausible.ClickhouseRepo,
                 "SELECT revenue_source_amount FROM events_v2 WHERE name = 'revenue-dump-as-max-int'"
               )

      assert dumped == 18_446_744_073_709_551_615
    end
  end
end
