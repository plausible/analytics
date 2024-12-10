defmodule Plausible.Workers.TrafficChangeNotifierTest do
  use Plausible.DataCase, async: true
  use Bamboo.Test
  use Plausible.Teams.Test
  import Double
  alias Plausible.Workers.TrafficChangeNotifier

  describe "drops" do
    test "does not notify anyone if we've stopped accepting traffic for the owner" do
      user = new_user(team: [accept_traffic_until: Date.utc_today()])
      site = new_site(owner: user)

      insert(:drop_notification,
        site: site,
        threshold: 10,
        recipients: ["jerod@example.com", "uku@example.com"]
      )

      clickhouse_stub =
        stub(Plausible.Stats.Clickhouse, :current_visitors_12h, fn _site -> 1 end)

      TrafficChangeNotifier.perform(nil, clickhouse_stub)

      assert_no_emails_delivered()
    end

    test "does notify if threshold reached and we're accepting traffic" do
      user = new_user(team: [accept_traffic_until: Date.utc_today() |> Date.add(+1)])
      site = new_site(owner: user)

      insert(:drop_notification,
        site: site,
        threshold: 10,
        recipients: ["jerod@example.com"]
      )

      clickhouse_stub =
        stub(Plausible.Stats.Clickhouse, :current_visitors_12h, fn _site -> 1 end)

      TrafficChangeNotifier.perform(nil, clickhouse_stub)

      assert_email_delivered_with(
        subject: "Traffic Drop on #{site.domain}",
        to: [nil: "jerod@example.com"]
      )
    end

    test "does not notify anyone if current visitors does not drop below notification threshold" do
      site = insert(:site)

      insert(:drop_notification,
        site: site,
        threshold: 10,
        recipients: ["jerod@example.com", "uku@example.com"]
      )

      clickhouse_stub =
        stub(Plausible.Stats.Clickhouse, :current_visitors_12h, fn _site -> 11 end)

      TrafficChangeNotifier.perform(nil, clickhouse_stub)

      assert_no_emails_delivered()
    end

    test "notifies all recipients when traffic drops under configured threshold" do
      site = new_site()

      insert(:drop_notification,
        site: site,
        threshold: 10,
        recipients: ["jerod@example.com", "uku@example.com"]
      )

      clickhouse_stub =
        stub(Plausible.Stats.Clickhouse, :current_visitors_12h, fn _site -> 7 end)

      TrafficChangeNotifier.perform(nil, clickhouse_stub)

      assert_email_delivered_with(
        subject: "Traffic Drop on #{site.domain}",
        to: [nil: "jerod@example.com"]
      )

      assert_email_delivered_with(
        subject: "Traffic Drop on #{site.domain}",
        to: [nil: "uku@example.com"]
      )
    end

    test "does not notify anyone if a notification already went out in the last 12 hours" do
      site = new_site()

      insert(:drop_notification,
        site: site,
        threshold: 10,
        recipients: ["uku@example.com"]
      )

      clickhouse_stub =
        stub(Plausible.Stats.Clickhouse, :current_visitors_12h, fn _site -> 4 end)

      TrafficChangeNotifier.perform(nil, clickhouse_stub)

      assert_email_delivered_with(
        subject: "Traffic Drop on #{site.domain}",
        to: [nil: "uku@example.com"]
      )

      TrafficChangeNotifier.perform(nil, clickhouse_stub)

      assert_no_emails_delivered()
    end

    test "adds settings link if recipient has access to the site" do
      user = new_user(email: "robert@example.com")
      site = new_site(domain: "example.com", owner: user)

      insert(:drop_notification,
        site: site,
        threshold: 10,
        recipients: ["robert@example.com"]
      )

      clickhouse_stub =
        stub(Plausible.Stats.Clickhouse, :current_visitors_12h, fn _site -> 6 end)

      TrafficChangeNotifier.perform(nil, clickhouse_stub)

      assert_email_delivered_with(
        html_body: ~r|http://localhost:8000/example.com/installation\?flow=review|
      )
    end
  end

  describe "spikes" do
    test "does not notify anyone if current visitors does not exceed notification threshold" do
      site = insert(:site)

      insert(:spike_notification,
        site: site,
        threshold: 10,
        recipients: ["jerod@example.com", "uku@example.com"]
      )

      clickhouse_stub =
        stub(Plausible.Stats.Clickhouse, :current_visitors, fn _site -> 5 end)
        |> stub(:top_sources_for_spike, fn _site, _query, _limit, _page -> [] end)

      TrafficChangeNotifier.perform(nil, clickhouse_stub)

      assert_no_emails_delivered()
    end

    test "notifies all recipients when traffic is higher than configured threshold" do
      site = new_site()

      insert(:spike_notification,
        site: site,
        threshold: 10,
        recipients: ["jerod@example.com", "uku@example.com"]
      )

      clickhouse_stub =
        stub(Plausible.Stats.Clickhouse, :current_visitors, fn _site -> 10 end)
        |> stub(:top_sources_for_spike, fn _site, _query, _limit, _page -> [] end)

      TrafficChangeNotifier.perform(nil, clickhouse_stub)

      assert_email_delivered_with(
        subject: "Traffic Spike on #{site.domain}",
        to: [nil: "jerod@example.com"]
      )

      assert_email_delivered_with(
        subject: "Traffic Spike on #{site.domain}",
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
        stub(Plausible.Stats.Clickhouse, :current_visitors, fn _site -> 10 end)
        |> stub(:top_sources_for_spike, fn _site, _query, _limit, _page -> [] end)

      TrafficChangeNotifier.perform(nil, clickhouse_stub)

      assert_no_emails_delivered()
    end

    test "does not notify anyone if a notification already went out in the last 12 hours" do
      site = new_site()
      insert(:spike_notification, site: site, threshold: 10, recipients: ["uku@example.com"])

      clickhouse_stub =
        stub(Plausible.Stats.Clickhouse, :current_visitors, fn _site -> 10 end)
        |> stub(:top_sources_for_spike, fn _site, _query, _limit, _page -> [] end)

      TrafficChangeNotifier.perform(nil, clickhouse_stub)

      assert_email_delivered_with(
        subject: "Traffic Spike on #{site.domain}",
        to: [nil: "uku@example.com"]
      )

      TrafficChangeNotifier.perform(nil, clickhouse_stub)

      assert_no_emails_delivered()
    end

    test "adds a dashboard link if recipient has access to the site" do
      user = new_user(email: "robert@example.com")
      site = new_site(domain: "example.com", owner: user)
      insert(:spike_notification, site: site, threshold: 10, recipients: ["robert@example.com"])

      clickhouse_stub =
        stub(Plausible.Stats.Clickhouse, :current_visitors, fn _site -> 10 end)
        |> stub(:top_sources_for_spike, fn _site, _query, _limit, _page -> [] end)

      TrafficChangeNotifier.perform(nil, clickhouse_stub)

      assert_email_delivered_with(html_body: ~r/View dashboard:\s+<a href=\"http.+\/example.com/)
    end
  end
end
