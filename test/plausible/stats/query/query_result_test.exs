defmodule Plausible.Stats.Query.QueryResultTest do
  use Plausible.DataCase, async: true
  alias Plausible.Stats.{Query, QueryRunner}

  setup do
    user = insert(:user)

    site =
      new_site(
        owner: user,
        inserted_at: ~N[2020-01-01T00:00:00],
        stats_start_date: ~D[2020-01-01]
      )

    {:ok, site: site}
  end

  test "parse_and_build!/2 raises on error on site_id mismatch", %{site: site} do
    assert_raise FunctionClauseError, fn ->
      Query.parse_and_build!(
        site,
        %{
          "site_id" => "different"
        }
      )
    end
  end

  test "parse_and_build!/2 raises on schema validation error", %{site: site} do
    assert_raise RuntimeError,
                 ~s/Failed to build query: "#: Required properties metrics, date_range were not present."/,
                 fn ->
                   Query.parse_and_build!(
                     site,
                     %{
                       "site_id" => site.domain
                     }
                   )
                 end
  end
end
