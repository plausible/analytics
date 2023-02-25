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

site = Plausible.Factory.insert(:site, domain: "dummy.site")

<<<<<<< HEAD
membership = Plausible.Factory.insert(:site_membership, user: user, site: site, role: :owner)
=======
_membership = Plausible.Factory.insert(:site_membership, user: user, site: site, role: :owner)
>>>>>>> 867dad6da7bb361f584d5bd35582687f90afb7e1

put_random_time = fn date ->
  random_time = Time.new!(:rand.uniform(23), :rand.uniform(59), 0)

  date
  |> NaiveDateTime.new!(random_time)
  |> NaiveDateTime.truncate(:second)
end

<<<<<<< HEAD
Enum.flat_map(-720..0, fn day_index ->
  number_of_events = :rand.uniform(500)
  date = Date.add(Date.utc_today(), day_index)

  attrs = [
    domain: site.domain,
    hostname: site.domain,
    timestamp: fn -> put_random_time.(date) end,
    referrer_source: fn -> Enum.random(["", "Facebook", "Twitter", "DuckDuckGo", "Google"]) end,
    browser: fn -> Enum.random(["Edge", "Chrome", "Safari", "Firefox", "Vivaldi"]) end,
    browser_version: fn -> 0..50 |> Enum.random() |> to_string() end,
    country_code: fn -> Enum.random(["ZZ", "BR", "EE", "US", "DE", "PL", ""]) end,
    screen_size: fn -> Enum.random(["Mobile", "Tablet", "Desktop", "Laptop"]) end,
    operating_system: fn -> Enum.random(["Windows", "macOS", "Linux"]) end,
    operating_system_version: fn -> 0..15 |> Enum.random() |> to_string() end
  ]

  Plausible.Factory.build_list(number_of_events, :pageview, attrs)
=======
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

Enum.flat_map(-720..0, fn day_index ->
  date = Date.add(Date.utc_today(), day_index)
  number_of_events = 0..:rand.uniform(500)

  Enum.map(number_of_events, fn _ ->
    geolocation = Enum.random(geolocations)

    [
      domain: site.domain,
      hostname: site.domain,
      timestamp: put_random_time.(date),
      referrer_source: Enum.random(["", "Facebook", "Twitter", "DuckDuckGo", "Google"]),
      browser: Enum.random(["Edge", "Chrome", "Safari", "Firefox", "Vivaldi"]),
      browser_version: to_string(Enum.random(0..50)),
      screen_size: Enum.random(["Mobile", "Tablet", "Desktop", "Laptop"]),
      operating_system: Enum.random(["Windows", "macOS", "Linux"]),
      operating_system_version: to_string(Enum.random(0..15))
    ]
    |> Keyword.merge(geolocation)
    |> then(&Plausible.Factory.build(:pageview, &1))
  end)
>>>>>>> 867dad6da7bb361f584d5bd35582687f90afb7e1
end)
|> Plausible.TestUtils.populate_stats()
