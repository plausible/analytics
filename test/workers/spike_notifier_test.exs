defmodule Plausible.Workers.SpikeNotifierTest do
  use Plausible.DataCase
  use Bamboo.Test
  import Double
  alias Plausible.Workers.SpikeNotifier

  test "does not notify anyone if current visitors does not exceed notification threshold" do
    site = insert(:site)

    insert(:spike_notification,
      site: site,
      threshold: 10,
      recipients: ["jerod@example.com", "uku@example.com"]
    )

    clickhouse_stub =
      stub(Plausible.Stats.Clickhouse, :current_visitors, fn _site, _query -> 5 end)
      |> stub(:top_sources, fn _site, _query, _limit, _page, _show_noref -> [] end)

    SpikeNotifier.perform(nil, clickhouse_stub)

    assert_no_emails_delivered()
  end

  test "notifies all recipients when traffic is higher than configured threshold" do
    site = insert(:site)

    insert(:spike_notification,
      site: site,
      threshold: 10,
      recipients: ["jerod@example.com", "uku@example.com"]
    )

    clickhouse_stub =
      stub(Plausible.Stats.Clickhouse, :current_visitors, fn _site, _query -> 10 end)
      |> stub(:top_sources, fn _site, _query, _limit, _page, _show_noref -> [] end)

    SpikeNotifier.perform(nil, clickhouse_stub)

    assert_email_delivered_with(
      subject: "Traffic spike on #{site.domain}",
      to: [nil: "jerod@example.com"]
    )

    assert_email_delivered_with(
      subject: "Traffic spike on #{site.domain}",
      to: [nil: "uku@example.com"]
    )
  end

  test "does not check site if it is locked" do
    site = insert(:site, locked: true)

    insert(:spike_notification,
      site: site,
      threshold: 10,
      recipients: ["uku@example.com"]
    )

    clickhouse_stub =
      stub(Plausible.Stats.Clickhouse, :current_visitors, fn _site, _query -> 10 end)
      |> stub(:top_sources, fn _site, _query, _limit, _page, _show_noref -> [] end)

    SpikeNotifier.perform(nil, clickhouse_stub)

    assert_no_emails_delivered()
  end

  test "does not notify anyone if a notification already went out in the last 12 hours" do
    site = insert(:site)
    insert(:spike_notification, site: site, threshold: 10, recipients: ["uku@example.com"])

    clickhouse_stub =
      stub(Plausible.Stats.Clickhouse, :current_visitors, fn _site, _query -> 10 end)
      |> stub(:top_sources, fn _site, _query, _limit, _page, _show_noref -> [] end)

    SpikeNotifier.perform(nil, clickhouse_stub)

    assert_email_delivered_with(
      subject: "Traffic spike on #{site.domain}",
      to: [nil: "uku@example.com"]
    )

    SpikeNotifier.perform(nil, clickhouse_stub)

    assert_no_emails_delivered()
  end
end
