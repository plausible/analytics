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

user = Plausible.Factory.insert(:user, email: "user@plausible.test", password: "plausible")

FunWithFlags.enable(:funnels)
FunWithFlags.enable(:props)

native_stats_range =
  Date.range(
    Date.add(Date.utc_today(), -720),
    Date.utc_today()
  )

imported_stats_range =
  Date.range(
    Date.add(native_stats_range.first, -360),
    Date.add(native_stats_range.first, -1)
  )

long_random_paths =
  for _ <- 1..100 do
    l = Enum.random(40..300)
    "/long/#{l}/path/#{String.duplicate("0x", l)}/end"
  end

long_random_urls =
  for path <- long_random_paths do
    "https://dummy.site#{path}"
  end

site =
  Plausible.Factory.insert(:site,
    domain: "dummy.site",
    native_stats_start_at: NaiveDateTime.new!(native_stats_range.first, ~T[00:00:00]),
    stats_start_date: NaiveDateTime.new!(imported_stats_range.first, ~T[00:00:00])
  )

{:ok, goal1} = Plausible.Goals.create(site, %{"page_path" => "/"})
{:ok, goal2} = Plausible.Goals.create(site, %{"page_path" => "/register"})
{:ok, goal3} = Plausible.Goals.create(site, %{"page_path" => "/login"})
{:ok, goal4} = Plausible.Goals.create(site, %{"event_name" => "Purchase", "currency" => "USD"})
{:ok, goal5} = Plausible.Goals.create(site, %{"page_path" => Enum.random(long_random_paths)})
{:ok, outbound} = Plausible.Goals.create(site, %{"event_name" => "Outbound Link: Click"})

{:ok, _funnel} =
  Plausible.Funnels.create(site, "From homepage to login", [
    %{"goal_id" => goal1.id},
    %{"goal_id" => goal2.id},
    %{"goal_id" => goal3.id}
  ])

_membership = Plausible.Factory.insert(:site_membership, user: user, site: site, role: :owner)

put_random_time = fn
  date, 0 ->
    current_hour = Time.utc_now().hour
    current_minute = Time.utc_now().minute
    random_time = Time.new!(:rand.uniform(current_hour), :rand.uniform(current_minute - 1), 0)

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

native_stats_range
|> Enum.with_index()
|> Enum.flat_map(fn {date, index} ->
  Enum.map(0..Enum.random(1..500), fn _ ->
    geolocation = Enum.random(geolocations)

    [
      site_id: site.id,
      hostname: site.domain,
      timestamp: put_random_time.(date, index),
      referrer_source: Enum.random(["", "Facebook", "Twitter", "DuckDuckGo", "Google"]),
      browser: Enum.random(["Edge", "Chrome", "Safari", "Firefox", "Vivaldi"]),
      browser_version: to_string(Enum.random(0..50)),
      screen_size: Enum.random(["Mobile", "Tablet", "Desktop", "Laptop"]),
      operating_system: Enum.random(["Windows", "macOS", "Linux"]),
      operating_system_version: to_string(Enum.random(0..15)),
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
      user_id: Enum.random(1..1200)
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

    [
      name: goal4.event_name,
      site_id: site.id,
      hostname: site.domain,
      timestamp: put_random_time.(date, index),
      referrer_source: Enum.random(["", "Facebook", "Twitter", "DuckDuckGo", "Google"]),
      browser: Enum.random(["Edge", "Chrome", "Safari", "Firefox", "Vivaldi"]),
      browser_version: to_string(Enum.random(0..50)),
      screen_size: Enum.random(["Mobile", "Tablet", "Desktop", "Laptop"]),
      operating_system: Enum.random(["Windows", "macOS", "Linux"]),
      operating_system_version: to_string(Enum.random(0..15)),
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
      revenue_reporting_currency: "USD"
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

    [
      name: outbound.event_name,
      site_id: site.id,
      hostname: site.domain,
      timestamp: put_random_time.(date, index),
      referrer_source: Enum.random(["", "Facebook", "Twitter", "DuckDuckGo", "Google"]),
      browser: Enum.random(["Edge", "Chrome", "Safari", "Firefox", "Vivaldi"]),
      browser_version: to_string(Enum.random(0..50)),
      screen_size: Enum.random(["Mobile", "Tablet", "Desktop", "Laptop"]),
      operating_system: Enum.random(["Windows", "macOS", "Linux"]),
      operating_system_version: to_string(Enum.random(0..15)),
      user_id: Enum.random(1..1200),
      "meta.key": ["url"],
      "meta.value": [
        Enum.random(long_random_urls)
      ]
    ]
    |> Keyword.merge(geolocation)
    |> then(&Plausible.Factory.build(:event, &1))
  end)
end)
|> Plausible.TestUtils.populate_stats()

site =
  site
  |> Plausible.Site.start_import(
    imported_stats_range.first,
    imported_stats_range.last,
    "Google Analytics"
  )
  |> Plausible.Repo.update!()

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
|> then(&Plausible.TestUtils.populate_stats(site, &1))

site
|> Plausible.Site.import_success()
|> Plausible.Repo.update!()
