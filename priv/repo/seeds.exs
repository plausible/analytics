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

membership = Plausible.Factory.insert(:site_membership, user: user, site: site, role: :owner)

put_random_time = fn date ->
  random_time = Time.new!(:rand.uniform(23), :rand.uniform(59), 0)

  date
  |> NaiveDateTime.new!(random_time)
  |> NaiveDateTime.truncate(:second)
end

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
end)
|> Plausible.TestUtils.populate_stats()
