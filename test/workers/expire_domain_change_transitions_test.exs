defmodule Plausible.Workers.ExpireDomainChangeTransitionsTest do
  use Plausible.DataCase, async: true
  alias Plausible.Workers.ExpireDomainChangeTransitions
  alias Plausible.Site
  alias Plausible.Sites

  import ExUnit.CaptureLog

  test "doesn't log when there is nothing to do" do
    log =
      capture_log(fn ->
        assert :ok = ExpireDomainChangeTransitions.perform(nil)
      end)

    refute log =~ "Expired"
  end

  test "expires domains selectively after change and logs the result" do
    now = NaiveDateTime.utc_now()
    yesterday = now |> NaiveDateTime.add(-60 * 60 * 24, :second)
    three_days_ago = now |> NaiveDateTime.add(-60 * 60 * 72, :second)
    long_time_ago = now |> NaiveDateTime.add(-60 * 60 * 24 * 365, :second)

    insert(:site) |> Site.Domain.change("site1.example.com")
    insert(:site) |> Site.Domain.change("site2.example.com", at: yesterday)
    insert(:site) |> Site.Domain.change("site3.example.com", at: three_days_ago)
    insert(:site) |> Site.Domain.change("site4.example.com", at: long_time_ago)

    log =
      capture_log(fn ->
        assert :ok = ExpireDomainChangeTransitions.perform(nil)
      end)

    assert log =~ "Expired 2 from the domain change transition period"

    assert Sites.get_by_domain("site1.example.com").domain_changed_from
    assert Sites.get_by_domain("site2.example.com").domain_changed_from
    refute Sites.get_by_domain("site3.example.com").domain_changed_from
    refute Sites.get_by_domain("site4.example.com").domain_changed_from
  end
end
