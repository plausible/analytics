defmodule Plausible.Workers.TrafficChangeNotifierTest do
  use Plausible.DataCase, async: true
  use Bamboo.Test
  use Plausible.Teams.Test
  alias Plausible.Workers.TrafficChangeNotifier

  @view_dashboard_text "View dashboard"
  @review_installation_text "review your installation"

  describe "drops" do
    test "does not notify anyone if we've stopped accepting traffic for the owner" do
      user = new_user(team: [accept_traffic_until: Date.utc_today()])
      site = new_site(owner: user)

      insert(:drop_notification,
        site: site,
        threshold: 10,
        recipients: ["jerod@example.com", "uku@example.com"]
      )

      TrafficChangeNotifier.perform(nil)

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

      TrafficChangeNotifier.perform(nil)

      assert_email_delivered_with(
        subject: "Traffic drop on #{site.domain}",
        to: [nil: "jerod@example.com"]
      )
    end

    test "does not notify anyone if current visitors does not drop below notification threshold" do
      site = insert(:site)

      insert(:drop_notification,
        site: site,
        threshold: 2,
        recipients: ["jerod@example.com", "uku@example.com"]
      )

      populate_stats(site, [
        build(:pageview, timestamp: minutes_ago(2)),
        build(:pageview, timestamp: minutes_ago(1))
      ])

      TrafficChangeNotifier.perform(nil)

      assert_no_emails_delivered()
    end

    test "notifies all recipients when traffic drops under configured threshold" do
      site = new_site()

      insert(:drop_notification,
        site: site,
        threshold: 10,
        recipients: ["jerod@example.com", "uku@example.com"]
      )

      TrafficChangeNotifier.perform(nil)

      assert_email_delivered_with(
        subject: "Traffic drop on #{site.domain}",
        to: [nil: "jerod@example.com"]
      )

      assert_email_delivered_with(
        subject: "Traffic drop on #{site.domain}",
        to: [nil: "uku@example.com"]
      )
    end

    test "includes dashboard and installation links only when recipient is guest or team member" do
      owner = new_user()
      {:ok, team} = Plausible.Teams.get_or_create(owner)
      site = new_site(team: team)
      team_member = add_member(team, role: :admin)
      viewer_guest = add_guest(site, role: :viewer, user: new_user())
      random_email = "random@example.com"

      insert(:drop_notification,
        site: site,
        threshold: 10,
        recipients: [owner.email, team_member.email, viewer_guest.email, random_email]
      )

      TrafficChangeNotifier.perform(nil)

      expected_subject = "Traffic drop on #{site.domain}"

      four_emails =
        for _ <- 1..4 do
          assert_delivered_email_matches(%{
            html_body: html_body,
            subject: ^expected_subject,
            to: [nil: email]
          })

          %{to: email, html_body: html_body}
        end

      {[random_recipient_email], site_member_emails} =
        Enum.split_with(four_emails, &(&1.to == random_email))

      refute random_recipient_email.html_body =~ "View dashboard"

      Enum.each(site_member_emails, fn email ->
        assert email.html_body =~ "View dashboard"
      end)
    end

    test "does not link to site installation in a consolidated view traffic drop notification" do
      %{email: user_email} = user = new_user()
      {:ok, team} = Plausible.Teams.get_or_create(user)
      new_site(team: team)
      new_site(team: team)

      consolidated_view = new_consolidated_view(team)

      insert(:drop_notification,
        site: consolidated_view,
        threshold: 10,
        recipients: [user.email]
      )

      TrafficChangeNotifier.perform(nil)

      assert_delivered_email_matches(%{
        html_body: html_body,
        subject: "Traffic drop on your sites",
        to: [nil: ^user_email]
      })

      assert html_body =~ "across all your sites"
      assert html_body =~ @view_dashboard_text
      refute html_body =~ @review_installation_text
    end

    test "does not send notifications more than once every 12 hours" do
      site = new_site()

      insert(:drop_notification,
        site: site,
        threshold: 1,
        recipients: ["uku@example.com"]
      )

      TrafficChangeNotifier.perform(nil, ~N[2021-01-01 00:00:00])

      assert_email_delivered_with(
        subject: "Traffic drop on #{site.domain}",
        to: [nil: "uku@example.com"]
      )

      TrafficChangeNotifier.perform(nil, ~N[2021-01-01 11:59:59])

      assert_no_emails_delivered()

      TrafficChangeNotifier.perform(nil, ~N[2021-01-01 12:00:01])

      assert_email_delivered_with(
        subject: "Traffic drop on #{site.domain}",
        to: [nil: "uku@example.com"]
      )
    end

    test "adds settings link if recipient has access to the site" do
      user = new_user(email: "robert@example.com")
      site = new_site(domain: "example.com", owner: user)

      insert(:drop_notification,
        site: site,
        threshold: 10,
        recipients: ["robert@example.com"]
      )

      TrafficChangeNotifier.perform(nil)

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
        threshold: 2,
        recipients: ["jerod@example.com", "uku@example.com"]
      )

      populate_stats(site, [build(:pageview, timestamp: minutes_ago(1))])

      TrafficChangeNotifier.perform(nil)

      assert_no_emails_delivered()
    end

    test "notifies all recipients when traffic is higher than configured threshold" do
      site = new_site()

      insert(:spike_notification,
        site: site,
        threshold: 2,
        recipients: ["jerod@example.com", "uku@example.com"]
      )

      populate_stats(site, [
        build(:pageview, timestamp: minutes_ago(3)),
        build(:pageview, timestamp: minutes_ago(2)),
        build(:pageview, timestamp: minutes_ago(1))
      ])

      TrafficChangeNotifier.perform(nil)

      assert_email_delivered_with(
        subject: "Traffic spike on #{site.domain}",
        to: [nil: "jerod@example.com"]
      )

      assert_email_delivered_with(
        subject: "Traffic spike on #{site.domain}",
        to: [nil: "uku@example.com"]
      )
    end

    test "notifies traffic spike on consolidated view" do
      {:ok, team} = new_user() |> Plausible.Teams.get_or_create()
      site1 = new_site(team: team)
      site2 = new_site(team: team)

      consolidated_view = new_consolidated_view(team)

      insert(:spike_notification,
        site: consolidated_view,
        threshold: 2,
        recipients: ["uku@example.com"]
      )

      populate_stats(site1, [
        build(:pageview, referrer_source: "Google", pathname: "/b", timestamp: minutes_ago(1)),
        build(:pageview, referrer_source: "Google", pathname: "/a", timestamp: minutes_ago(2))
      ])

      populate_stats(site2, [
        build(:pageview, referrer_source: "Twitter", pathname: "/a", timestamp: minutes_ago(3))
      ])

      TrafficChangeNotifier.perform(nil)

      assert_delivered_email_matches(%{
        html_body: html_body,
        subject: "Traffic spike on your sites",
        to: [nil: "uku@example.com"]
      })

      assert html_body =~ "across all your sites"

      assert html_body =~ "The top sources for current visitors:"
      assert html_body =~ "<b>2</b> visitors from <b>Google</b>"
      assert html_body =~ "<b>1</b> visitor from <b>Twitter</b>"

      assert html_body =~ "Your top pages being visited:"
      assert html_body =~ "<b>2</b> visitors on <b>/a</b>"
      assert html_body =~ "<b>1</b> visitor on <b>/b</b>"
    end

    test "ignores 'Direct / None' source" do
      site = new_site()

      insert(:spike_notification,
        site: site,
        threshold: 5,
        recipients: ["uku@example.com"]
      )

      populate_stats(site, [
        build(:pageview, referrer_source: "A", timestamp: minutes_ago(1)),
        build(:pageview, referrer_source: "A", timestamp: minutes_ago(1)),
        build(:pageview, referrer_source: "A", timestamp: minutes_ago(1)),
        build(:pageview, referrer_source: "B", timestamp: minutes_ago(1)),
        build(:pageview, referrer_source: "B", timestamp: minutes_ago(1)),
        build(:pageview, referrer_source: "C", timestamp: minutes_ago(1)),
        build(:pageview, timestamp: minutes_ago(1)),
        build(:pageview, timestamp: minutes_ago(1))
      ])

      TrafficChangeNotifier.perform(nil)

      assert_delivered_email_matches(%{
        to: [nil: "uku@example.com"],
        html_body: html_body
      })

      assert html_body =~ "The top sources for current visitors:"
      assert html_body =~ "<b>3</b> visitors from <b>A</b>"
      assert html_body =~ "<b>2</b> visitors from <b>B</b>"
      assert html_body =~ "<b>1</b> visitor from <b>C</b>"
      assert html_body =~ "There are currently <b>8</b>"
    end

    test "does not list sources at all when everything is 'Direct / None'" do
      site = new_site()

      insert(:spike_notification,
        site: site,
        threshold: 1,
        recipients: ["uku@example.com"]
      )

      populate_stats(site, [
        build(:pageview, timestamp: minutes_ago(1)),
        build(:pageview, timestamp: minutes_ago(1))
      ])

      TrafficChangeNotifier.perform(nil)

      assert_delivered_email_matches(%{
        to: [nil: "uku@example.com"],
        html_body: html_body
      })

      refute html_body =~ "The top sources for current visitors:"
      assert html_body =~ "There are currently <b>2</b>"
    end

    test "includes top 3 pages" do
      site = new_site()

      insert(:spike_notification,
        site: site,
        threshold: 10,
        recipients: ["uku@example.com"]
      )

      populate_stats(site, [
        build(:pageview, pathname: "/one", timestamp: minutes_ago(1)),
        build(:pageview, pathname: "/one", timestamp: minutes_ago(1)),
        build(:pageview, pathname: "/one", timestamp: minutes_ago(1)),
        build(:pageview, pathname: "/one", timestamp: minutes_ago(1)),
        build(:pageview, pathname: "/two", timestamp: minutes_ago(1)),
        build(:pageview, pathname: "/two", timestamp: minutes_ago(1)),
        build(:pageview, pathname: "/two", timestamp: minutes_ago(1)),
        build(:pageview, timestamp: minutes_ago(1)),
        build(:pageview, timestamp: minutes_ago(1)),
        build(:pageview, pathname: "/not-this-one", timestamp: minutes_ago(1))
      ])

      TrafficChangeNotifier.perform(nil)

      assert_delivered_email_matches(%{
        to: [nil: "uku@example.com"],
        html_body: html_body
      })

      assert html_body =~ "There are currently <b>10</b>"

      assert html_body =~ "Your top pages being visited:"
      assert html_body =~ "<b>4</b> visitors on <b>/one</b>"
      assert html_body =~ "<b>3</b> visitors on <b>/two</b>"
      assert html_body =~ "<b>2</b> visitors on <b>/</b>"

      refute html_body =~ "/not-this-one"
    end

    test "does not check site if it is locked" do
      site = new_site()
      site.team |> Ecto.Changeset.change(locked: true) |> Repo.update!()

      insert(:spike_notification,
        site: site,
        threshold: 1,
        recipients: ["uku@example.com"]
      )

      populate_stats(site, [
        build(:pageview, timestamp: minutes_ago(1)),
        build(:pageview, timestamp: minutes_ago(1))
      ])

      TrafficChangeNotifier.perform(nil)

      assert_no_emails_delivered()
    end

    test "does not send notifications more than once every 12 hours" do
      site = new_site()
      insert(:spike_notification, site: site, threshold: 1, recipients: ["uku@example.com"])

      populate_stats(site, [
        build(:pageview, timestamp: minutes_ago(1)),
        build(:pageview, timestamp: minutes_ago(1))
      ])

      TrafficChangeNotifier.perform(nil)

      assert_email_delivered_with(
        subject: "Traffic spike on #{site.domain}",
        to: [nil: "uku@example.com"]
      )

      TrafficChangeNotifier.perform(nil)

      assert_no_emails_delivered()
    end

    test "adds a dashboard link if recipient has access to the site" do
      user = new_user(email: "robert@example.com")
      site = new_site(domain: "example.com", owner: user)
      insert(:spike_notification, site: site, threshold: 1, recipients: ["robert@example.com"])

      populate_stats(site, [
        build(:pageview, timestamp: minutes_ago(1)),
        build(:pageview, timestamp: minutes_ago(1))
      ])

      TrafficChangeNotifier.perform(nil)

      assert_delivered_email_matches(%{html_body: html_body})
      assert html_body =~ @view_dashboard_text
    end
  end

  def minutes_ago(min) do
    NaiveDateTime.utc_now(:second) |> NaiveDateTime.add(-min, :minute)
  end
end
