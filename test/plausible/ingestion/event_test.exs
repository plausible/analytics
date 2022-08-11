defmodule Plausible.Ingestion.EventTest do
  use Plausible.DataCase

  def get_event(domain) do
    Plausible.TestUtils.eventually(fn ->
      Plausible.Event.WriteBuffer.flush()

      event =
        Plausible.ClickhouseRepo.one(
          from e in Plausible.ClickhouseEvent, where: e.domain == ^domain
        )

      {!is_nil(event), event}
    end)
  end

  @valid_request %Plausible.Ingestion.Request{
    remote_ip: "2.2.2.2",
    user_agent:
      "Mozilla/5.0 (iPad; U; CPU OS 3_2_1 like Mac OS X; en-us) AppleWebKit/531.21.10 (KHTML, like Gecko) Mobile/7B405",
    event_name: "pageview",
    url: "http://skywalker.test",
    referrer: "http://m.facebook.test/",
    screen_width: 1440,
    hash_mode: nil,
    utm_medium: "utm_medium",
    utm_source: "utm_source",
    utm_campaign: "utm_campaign",
    utm_content: "utm_content",
    utm_term: "utm_term",
    source_param: "source_param",
    ref_param: "ref_param"
  }

  test "build_and_buffer/3 creates an event" do
    assert {:ok, _stash} =
             @valid_request
             |> Map.put(:domain, "plausible-ingestion-event-basic.test")
             |> Plausible.Ingestion.Event.build_and_buffer()

    assert %Plausible.ClickhouseEvent{
             session_id: session_id,
             user_id: user_id,
             domain: "plausible-ingestion-event-basic.test",
             browser: "Safari",
             browser_version: "",
             city_geoname_id: 2_988_507,
             country_code: "FR",
             hostname: "skywalker.test",
             "meta.key": [],
             "meta.value": [],
             name: "pageview",
             operating_system: "iOS",
             operating_system_version: "3.2",
             pathname: "/",
             referrer: "m.facebook.test",
             referrer_source: "utm_source",
             screen_size: "Desktop",
             subdivision1_code: "FR-IDF",
             subdivision2_code: "FR-75",
             transferred_from: "",
             utm_campaign: "utm_campaign",
             utm_content: "utm_content",
             utm_medium: "utm_medium",
             utm_source: "utm_source",
             utm_term: "utm_term"
           } = get_event("plausible-ingestion-event-basic.test")

    assert is_integer(session_id)
    assert is_integer(user_id)
  end

  test "build_and_buffer/3 stashes user_agent and geolocation" do
    assert {:ok, stash} =
             @valid_request
             |> Map.put(:domain, "plausible-ingestion-event-stash-1.test")
             |> Plausible.Ingestion.Event.build_and_buffer([:user_agent, :geolocation])

    assert %Plausible.ClickhouseEvent{
             browser: "Safari",
             browser_version: "",
             operating_system: "iOS",
             operating_system_version: "3.2",
             subdivision1_code: "FR-IDF",
             subdivision2_code: "FR-75",
             city_geoname_id: 2_988_507,
             country_code: "FR"
           } = get_event("plausible-ingestion-event-stash-1.test")

    assert {:ok, _stash} =
             @valid_request
             |> Map.put(:domain, "plausible-ingestion-event-stash-2.test")
             |> Map.put(:user_agent, "Dummy UA")
             |> Map.put(:remote_ip, "127.0.0.1")
             |> Plausible.Ingestion.Event.build_and_buffer([:user_agent, :geolocation], stash)

    assert %Plausible.ClickhouseEvent{
             browser: "Safari",
             browser_version: "",
             operating_system: "iOS",
             operating_system_version: "3.2",
             subdivision1_code: "FR-IDF",
             subdivision2_code: "FR-75",
             city_geoname_id: 2_988_507,
             country_code: "FR"
           } = get_event("plausible-ingestion-event-stash-2.test")
  end
end
