# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Plausible.Repo.insert!(%Plausible.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
use Plausible

import Plausible.Teams.Test

FunWithFlags.enable(:starter_tier)

Plausible.Repo.transaction(fn ->
  Carbonite.override_mode(Plausible.Repo, to: :ignore)

  words =
    for i <- 0..(:erlang.system_info(:atom_count) - 1),
        do: :erlang.binary_to_term(<<131, 75, i::24>>)

  user = new_user(email: "user@plausible.test", password: "plausible")

  native_stats_range =
    Date.range(
      Date.add(Date.utc_today(), -720),
      Date.utc_today()
    )

  imported_stats_range =
    Date.range(
      Date.add(native_stats_range.first, -180),
      Date.add(native_stats_range.first, -1)
    )

  long_random_paths =
    for _ <- 1..100 do
      path =
        words
        |> Enum.shuffle()
        |> Enum.take(Enum.random(1..20))
        |> Enum.join("/")

      "/#{path}.html"
    end

  long_random_paths = ["/", "/register", "/login", "/about"] ++ long_random_paths

  long_random_urls =
    for path <- long_random_paths do
      "https://dummy.site#{path}"
    end

  site =
    new_site(
      domain: "dummy.site",
      team: [
        native_stats_start_at: NaiveDateTime.new!(native_stats_range.first, ~T[00:00:00]),
        stats_start_date: NaiveDateTime.new!(imported_stats_range.first, ~T[00:00:00])
      ],
      owner: user
    )

  add_guest(site, user: new_user(name: "Arnold Wallaby", password: "plausible"), role: :viewer)
  add_guest(site, user: new_user(name: "Lois Lane", password: "plausible"), role: :editor)

  user2 = new_user(name: "Mary Jane", email: "user2@plausible.test", password: "plausible")
  site2 = new_site(domain: "computer.example.com", owner: user2)
  invite_guest(site2, user, inviter: user2, role: :viewer)

  solo_user = new_user(name: "Solo User", email: "solo@plausible.test", password: "plausible")
  new_site(domain: "mysolosite.com", owner: solo_user)
  {:ok, solo_team} = Plausible.Teams.get_or_create(solo_user)
  Plausible.Billing.DevSubscriptions.create(solo_team.id, "910413")

  Plausible.Factory.insert_list(29, :ip_rule, site: site)
  Plausible.Factory.insert(:country_rule, site: site, country_code: "PL")
  Plausible.Factory.insert(:country_rule, site: site, country_code: "EE")

  Plausible.Factory.insert(:google_auth,
    user: user,
    site: site,
    property: "sc-domain:dummy.test",
    expires: NaiveDateTime.add(NaiveDateTime.utc_now(), 3600)
  )

  # Plugins API: on dev environment, use "plausible-plugin-dev-seed-token" for "dummy.site" to authenticate
  seeded_token = Plausible.Plugins.API.Token.generate("seed-token")

  {:ok, _, _} =
    Plausible.Plugins.API.Tokens.create(site, "plausible-plugin-dev-seed-token", seeded_token)

  {:ok, site} = Plausible.Props.allow(site, ["logged_in"])

  {:ok, goal1} = Plausible.Goals.create(site, %{"page_path" => "/"})
  {:ok, goal2} = Plausible.Goals.create(site, %{"page_path" => "/register"})

  {:ok, goal3} =
    Plausible.Goals.create(site, %{"page_path" => "/login", "display_name" => "User logs in"})

  {:ok, revenue_goal} =
    Plausible.Goals.create(site, %{
      "event_name" => "Purchase",
      "currency" => "USD",
      "display_name" => "North America Purchases"
    })

  {:ok, _goal5} = Plausible.Goals.create(site, %{"page_path" => Enum.random(long_random_paths)})
  {:ok, outbound} = Plausible.Goals.create(site, %{"event_name" => "Outbound Link: Click"})

  if ee?() do
    {:ok, _funnel} =
      Plausible.Funnels.create(site, "From homepage to login", [
        %{"goal_id" => goal1.id},
        %{"goal_id" => goal2.id},
        %{"goal_id" => goal3.id}
      ])
  end

  geolocations = [
    [
      country_code: "IT",
      subdivision1_code: "IT-62",
      subdivision2_code: "IT-RM",
      city_geoname_id: 3_169_070
    ],
    [
      country_code: "EE",
      subdivision1_code: "EE-37",
      subdivision2_code: "EE-784",
      city_geoname_id: 588_409
    ],
    [
      country_code: "BR",
      subdivision1_code: "BR-SP",
      subdivision2_code: "",
      city_geoname_id: 3_448_439
    ],
    [
      country_code: "PL",
      subdivision1_code: "PL-14",
      subdivision2_code: "",
      city_geoname_id: 756_135
    ],
    [
      country_code: "DE",
      subdivision1_code: "DE-BE",
      subdivision2_code: "",
      city_geoname_id: 2_950_159
    ],
    [
      country_code: "US",
      subdivision1_code: "US-CA",
      subdivision2_code: "",
      city_geoname_id: 5_391_959
    ],
    []
  ]

  sources = [
    "",
    "Facebook",
    "Twitter",
    "DuckDuckGo",
    "Google",
    "opensource.com",
    "indiehackers.com"
  ]

  utm_medium = %{
    "" => ["email", ""],
    "Google" => ["cpc", ""],
    "Facebook" => ["social", "cpc"],
    "Twitter" => ["social"]
  }

  random_event_data = fn ->
    referrer_source = Enum.random(sources)

    [
      site_id: site.id,
      hostname: Enum.random(["en.dummy.site", "es.dummy.site", "dummy.site"]),
      referrer_source: referrer_source,
      browser: Enum.random(["Microsoft Edge", "Chrome", "curl", "Safari", "Firefox", "Vivaldi"]),
      browser_version: to_string(Enum.random(0..50)),
      screen_size: Enum.random(["Mobile", "Tablet", "Desktop", "Laptop"]),
      operating_system: Enum.random(["Windows", "Mac", "GNU/Linux"]),
      operating_system_version: to_string(Enum.random(0..15)),
      utm_medium: Enum.random(Map.get(utm_medium, referrer_source, [""])),
      utm_source: String.downcase(referrer_source),
      utm_campaign: Enum.random(["", "Referral", "Advertisement", "Email"]),
      pathname: Enum.random(long_random_paths),
      "meta.key": ["url", "logged_in"],
      "meta.value": [
        Enum.random(long_random_urls),
        Enum.random(["true", "false"])
      ]
    ]
    |> Keyword.merge(Enum.random(geolocations))
  end

  clickhouse_max_uint64 = 18_446_744_073_709_551_615

  with_random_time = fn date ->
    random_time = Time.new!(:rand.uniform(23), :rand.uniform(59), 0)

    date
    |> NaiveDateTime.new!(random_time)
    |> NaiveDateTime.truncate(:second)
  end

  next_event_timestamp = fn timestamp ->
    seconds_to_next_event = :rand.uniform(300)
    NaiveDateTime.add(timestamp, seconds_to_next_event)
  end

  native_stats_range
  |> Enum.flat_map(fn date ->
    n_visitors = 50 + :rand.uniform(150)

    Enum.flat_map(0..n_visitors, fn _ ->
      visit_start_timestamp = with_random_time.(date)
      user_id = :rand.uniform(clickhouse_max_uint64)

      event =
        random_event_data.()
        |> Keyword.merge(user_id: user_id)

      Enum.reduce(0..Enum.random(0..5), [], fn event_index, events ->
        timestamp =
          case events do
            [] -> visit_start_timestamp
            [event | _] -> next_event_timestamp.(event.timestamp)
          end

        event = Keyword.merge(event, timestamp: timestamp)

        to_insert =
          cond do
            event_index > 0 && :rand.uniform() < 0.1 ->
              event
              |> Keyword.merge(name: outbound.event_name)
              |> then(&[Plausible.Factory.build(:event, &1)])

            event_index > 0 && :rand.uniform() < 0.05 ->
              amount = Decimal.new(:rand.uniform(100))

              event
              |> Keyword.merge(name: revenue_goal.event_name)
              |> Keyword.merge(revenue_source_currency: "USD")
              |> Keyword.merge(revenue_source_amount: amount)
              |> Keyword.merge(revenue_reporting_currency: "USD")
              |> Keyword.merge(revenue_reporting_amount: amount)
              |> then(&[Plausible.Factory.build(:event, &1)])

            true ->
              pageview = Plausible.Factory.build(:pageview, event)

              engagement =
                Map.merge(pageview, %{
                  name: "engagement",
                  engagement_time: Enum.random(300..10000),
                  scroll_depth: Enum.random(1..100)
                })

              [engagement, pageview]
          end

        to_insert ++ events
      end)
      |> Enum.reverse()
    end)
  end)
  |> Plausible.TestUtils.populate_stats()

  site_import =
    site
    |> Plausible.Imported.SiteImport.create_changeset(user, %{
      source: :universal_analytics,
      start_date: imported_stats_range.first,
      end_date: imported_stats_range.last,
      legacy: false
    })
    |> Plausible.Imported.SiteImport.start_changeset()
    |> Plausible.Repo.insert!()

  imported_stats_range
  |> Enum.flat_map(fn date ->
    Enum.flat_map(0..Enum.random(1..50), fn _ ->
      pages_visits = Enum.random(1..15)

      [
        Plausible.Factory.build(:imported_visitors,
          date: date,
          pageviews: Enum.random(1..50),
          visitors: Enum.random(1..10),
          bounces: Enum.random(1..6),
          visits: Enum.random(1..15),
          visit_duration: Enum.random(1000..10000)
        ),
        Plausible.Factory.build(:imported_sources,
          date: date,
          source: Enum.random(sources),
          pageviews: Enum.random(1..50),
          visitors: Enum.random(1..10),
          bounces: Enum.random(1..6),
          visits: Enum.random(1..15),
          visit_duration: Enum.random(1000..10000)
        ),
        Plausible.Factory.build(:imported_pages,
          date: date,
          page: Enum.random(long_random_paths),
          visitors: Enum.random(1..10),
          visits: pages_visits,
          pageviews: Enum.random(1..50),
          exits: Enum.random(1..10),
          total_time_on_page: Enum.random(1000..10000),
          total_time_on_page_visits: pages_visits
        )
      ]
    end)
  end)
  |> then(&Plausible.TestUtils.populate_stats(site, site_import.id, &1))

  site_import
  |> Plausible.Imported.SiteImport.complete_changeset()
  |> Plausible.Repo.update!()
end)
