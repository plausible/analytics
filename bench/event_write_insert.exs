event = %Plausible.ClickhouseEventV2{
  name: "pageview",
  site_id: 3,
  hostname: "dummy.site",
  pathname: "/some-page",
  user_id: 6_744_441_728_453_009_796,
  session_id: 5_760_370_699_094_039_040,
  timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
  country_code: "KR",
  city_geoname_id: 123,
  screen_size: "Desktop",
  operating_system: "Mac",
  operating_system_version: "10.15",
  browser: "Opera",
  browser_version: "71.0"
}

Benchee.run(
  %{
    "insert" => fn -> Plausible.Event.WriteBuffer.insert(event) end
  },
  profile_after: true
)
