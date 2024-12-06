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
import Plausible.Teams.Test

words =
  for i <- 0..(:erlang.system_info(:atom_count) - 1),
      do: :erlang.binary_to_term(<<131, 75, i::24>>)

user = new_user(email: "user@plausible.test", password: "plausible")

native_stats_range =
  Date.range(
    Date.add(Date.utc_today(), -720),
    Date.utc_today()
  )

legacy_imported_stats_range =
  Date.range(
    Date.add(native_stats_range.first, -360),
    Date.add(native_stats_range.first, -180)
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

long_random_urls =
  for path <- long_random_paths do
    "https://dummy.site#{path}"
  end

site =
  new_site(
    domain: "dummy.site",
    team: [
      native_stats_start_at: NaiveDateTime.new!(native_stats_range.first, ~T[00:00:00]),
      stats_start_date: NaiveDateTime.new!(legacy_imported_stats_range.first, ~T[00:00:00])
    ],
    owner: user
  )

add_guest(site, user: new_user(name: "Arnold Wallaby", password: "plausible"), role: :viewer)

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

{:ok, goal1} = Plausible.Goals.create(site, %{"page_path" => "/"})
{:ok, goal2} = Plausible.Goals.create(site, %{"page_path" => "/register"})

{:ok, goal3} =
  Plausible.Goals.create(site, %{"page_path" => "/login", "display_name" => "User logs in"})

{:ok, goal4} =
  Plausible.Goals.create(site, %{
    "event_name" => "Purchase",
    "currency" => "USD",
    "display_name" => "North America Purchases"
  })

{:ok, _goal5} = Plausible.Goals.create(site, %{"page_path" => Enum.random(long_random_paths)})
{:ok, outbound} = Plausible.Goals.create(site, %{"event_name" => "Outbound Link: Click"})

if Plausible.ee?() do
  {:ok, _funnel} =
    Plausible.Funnels.create(site, "From homepage to login", [
      %{"goal_id" => goal1.id},
      %{"goal_id" => goal2.id},
      %{"goal_id" => goal3.id}
    ])
end

put_random_time = fn
  date, 0 ->
    current_hour = Time.utc_now().hour
    current_minute = Time.utc_now().minute

    random_time =
      Time.new!(
        Enum.random(0..current_hour),
        Enum.random(0..current_minute),
        0
      )

    date
    |> NaiveDateTime.new!(random_time)
    |> NaiveDateTime.truncate(:second)

  date, _ ->
    random_time = Time.new!(:rand.uniform(23), :rand.uniform(59), 0)

    date
    |> NaiveDateTime.new!(random_time)
    |> NaiveDateTime.truncate(:second)
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

sources = ["", "Facebook", "Twitter", "DuckDuckGo", "Google"]

utm_medium = %{
  "" => ["email", ""],
  "Facebook" => ["social"],
  "Twitter" => ["social"]
}

native_stats_range
|> Enum.with_index()
|> Enum.flat_map(fn {date, index} ->
  Enum.map(0..Enum.random(1..500), fn _ ->
    geolocation = Enum.random(geolocations)

    referrer_source = Enum.random(sources)

    [
      site_id: site.id,
      hostname: Enum.random(["en.dummy.site", "es.dummy.site", "dummy.site"]),
      timestamp: put_random_time.(date, index),
      referrer_source: referrer_source,
      browser: Enum.random(["Microsoft Edge", "Chrome", "curl", "Safari", "Firefox", "Vivaldi"]),
      browser_version: to_string(Enum.random(0..50)),
      screen_size: Enum.random(["Mobile", "Tablet", "Desktop", "Laptop"]),
      operating_system: Enum.random(["Windows", "Mac", "GNU/Linux"]),
      operating_system_version: to_string(Enum.random(0..15)),
      utm_medium: Enum.random(Map.get(utm_medium, referrer_source, [""])),
      utm_source: String.downcase(referrer_source),
      utm_campaign: Enum.random(["", "Referral", "Advertisement", "Email"]),
      pathname:
        Enum.random([
          "/",
          "/login",
          "/settings",
          "/register",
          "/docs",
          "/docs/1",
          "/docs/2" | long_random_paths
        ]),
      user_id: Enum.random(1..1200),
      "meta.key": ["url", "logged_in", "is_customer", "amount"],
      "meta.value": [
        Enum.random(long_random_urls),
        Enum.random(["true", "false"]),
        Enum.random(["true", "false"]),
        to_string(Enum.random(1..9000))
      ]
    ]
    |> Keyword.merge(geolocation)
    |> then(&Plausible.Factory.build(:pageview, &1))
  end)
end)
|> Plausible.TestUtils.populate_stats()

native_stats_range
|> Enum.with_index()
|> Enum.flat_map(fn {date, index} ->
  Enum.map(0..Enum.random(1..50), fn _ ->
    geolocation = Enum.random(geolocations)

    referrer_source = Enum.random(sources)

    [
      name: goal4.event_name,
      site_id: site.id,
      hostname: Enum.random(["en.dummy.site", "es.dummy.site", "dummy.site"]),
      timestamp: put_random_time.(date, index),
      referrer_source: Enum.random(["", "Facebook", "Twitter", "DuckDuckGo", "Google"]),
      browser: Enum.random(["Microsoft Edge", "Chrome", "Safari", "Firefox", "Vivaldi"]),
      browser_version: to_string(Enum.random(0..50)),
      screen_size: Enum.random(["Mobile", "Tablet", "Desktop", "Laptop"]),
      operating_system: Enum.random(["Windows", "Mac", "GNU/Linux"]),
      operating_system_version: to_string(Enum.random(0..15)),
      utm_medium: Enum.random(Map.get(utm_medium, referrer_source, [""])),
      utm_source: String.downcase(referrer_source),
      pathname:
        Enum.random([
          "/",
          "/login",
          "/settings",
          "/register",
          "/docs",
          "/docs/1",
          "/docs/2" | long_random_paths
        ]),
      user_id: Enum.random(1..1200),
      revenue_reporting_amount: Decimal.new(Enum.random(100..10000)),
      revenue_reporting_currency: "USD",
      "meta.key": ["url", "logged_in", "is_customer", "amount"],
      "meta.value": [
        Enum.random(long_random_urls),
        Enum.random(["true", "false"]),
        Enum.random(["true", "false"]),
        to_string(Enum.random(1..9000))
      ]
    ]
    |> Keyword.merge(geolocation)
    |> then(&Plausible.Factory.build(:event, &1))
  end)
end)
|> Plausible.TestUtils.populate_stats()

native_stats_range
|> Enum.with_index()
|> Enum.flat_map(fn {date, index} ->
  Enum.map(0..Enum.random(1..50), fn _ ->
    geolocation = Enum.random(geolocations)

    referrer_source = Enum.random(sources)

    [
      name: outbound.event_name,
      site_id: site.id,
      hostname: site.domain,
      timestamp: put_random_time.(date, index),
      referrer_source: referrer_source,
      browser: Enum.random(["Microsoft Edge", "Chrome", "Safari", "Firefox", "Vivaldi"]),
      browser_version: to_string(Enum.random(0..50)),
      screen_size: Enum.random(["Mobile", "Tablet", "Desktop", "Laptop"]),
      operating_system: Enum.random(["Windows", "Mac", "GNU/Linux"]),
      operating_system_version: to_string(Enum.random(0..15)),
      utm_medium: Enum.random(Map.get(utm_medium, referrer_source, [""])),
      utm_source: String.downcase(referrer_source),
      user_id: Enum.random(1..1200),
      "meta.key": ["url", "logged_in", "is_customer", "amount"],
      "meta.value": [
        Enum.random(long_random_urls),
        Enum.random(["true", "false"]),
        Enum.random(["true", "false"]),
        to_string(Enum.random(1..9000))
      ]
    ]
    |> Keyword.merge(geolocation)
    |> then(&Plausible.Factory.build(:event, &1))
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
  Enum.flat_map(0..Enum.random(1..500), fn _ ->
    [
      Plausible.Factory.build(:imported_visitors,
        date: date,
        pageviews: Enum.random(1..20),
        visitors: Enum.random(1..20),
        bounces: Enum.random(1..20),
        visits: Enum.random(1..200),
        visit_duration: Enum.random(1000..10000)
      ),
      Plausible.Factory.build(:imported_sources,
        date: date,
        source: Enum.random(["", "Facebook", "Twitter", "DuckDuckGo", "Google"]),
        visitors: Enum.random(1..20),
        visits: Enum.random(1..200),
        bounces: Enum.random(1..20),
        visit_duration: Enum.random(1000..10000)
      ),
      Plausible.Factory.build(:imported_pages,
        date: date,
        visitors: Enum.random(1..20),
        pageviews: Enum.random(1..20),
        exits: Enum.random(1..20),
        time_on_page: Enum.random(1000..10000)
      )
    ]
  end)
end)
|> then(&Plausible.TestUtils.populate_stats(site, site_import.id, &1))

site_import
|> Plausible.Imported.SiteImport.complete_changeset()
|> Plausible.Repo.update!()
