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
    remote_ip: "2.125.160.216",
    user_agent:
      "Mozilla/5.0 (iPad; U; CPU OS 3_2_1 like Mac OS X; en-us) AppleWebKit/531.21.10 (KHTML, like Gecko) Mobile/7B405",
    event_name: "pageview",
    url: "http://skywalker.test",
    referrer: "http://m.facebook.test/",
    screen_width: 1440,
    hash_mode: nil,
    query_params: %{
      "utm_medium" => "utm_medium",
      "utm_source" => "utm_source",
      "utm_campaign" => "utm_campaign",
      "utm_content" => "utm_content",
      "utm_term" => "utm_term",
      "source" => "source",
      "ref" => "ref"
    }
  }

  test "build_and_buffer/3 creates an event" do
    assert :ok ==
             @valid_request
             |> Map.put(:domain, "plausible-ingestion-event-basic.test")
             |> Plausible.Ingestion.Event.build_and_buffer()

    assert %Plausible.ClickhouseEvent{
             session_id: session_id,
             user_id: user_id,
             domain: "plausible-ingestion-event-basic.test",
             browser: "Safari",
             browser_version: "",
             city_geoname_id: 2_655_045,
             country_code: "GB",
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
             subdivision1_code: "GB-ENG",
             subdivision2_code: "GB-WBK",
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
end
