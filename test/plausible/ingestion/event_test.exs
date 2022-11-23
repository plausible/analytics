defmodule Plausible.Ingestion.EventTest do
  use Plausible.DataCase

  @valid_request %Plausible.Ingestion.Request{
    remote_ip: "2.2.2.2",
    user_agent:
      "Mozilla/5.0 (iPad; U; CPU OS 3_2_1 like Mac OS X; en-us) AppleWebKit/531.21.10 (KHTML, like Gecko) Mobile/7B405",
    event_name: "pageview",
    uri: URI.parse("http://skywalker.test"),
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

  describe "integration" do
    test "build_and_buffer/1 creates an event" do
      assert {:ok, %{buffered: [_], dropped: []}} =
               @valid_request
               |> Map.put(:domains, ["plausible-ingestion-event-basic.test"])
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

    test "build_and_buffer/1 takes multiple domains" do
      request = %Plausible.Ingestion.Request{
        @valid_request
        | domains: [
            "plausible-ingestion-event-multiple-1.test",
            "plausible-ingestion-event-multiple-2.test"
          ]
      }

      assert {:ok, %{buffered: [_, _], dropped: []}} =
               Plausible.Ingestion.Event.build_and_buffer(request)

      assert %Plausible.ClickhouseEvent{domain: "plausible-ingestion-event-multiple-1.test"} =
               get_event("plausible-ingestion-event-multiple-1.test")

      assert %Plausible.ClickhouseEvent{domain: "plausible-ingestion-event-multiple-2.test"} =
               get_event("plausible-ingestion-event-multiple-2.test")
    end

    test "build_and_buffer/1 drops invalid events" do
      request = %Plausible.Ingestion.Request{
        @valid_request
        | domains: ["plausible-ingestion-event-multiple-with-error-1.test", nil]
      }

      assert {:ok, %{buffered: [_], dropped: [dropped]}} =
               Plausible.Ingestion.Event.build_and_buffer(request)

      assert {:error, changeset} = dropped.drop_reason
      refute changeset.valid?

      assert %Plausible.ClickhouseEvent{
               domain: "plausible-ingestion-event-multiple-with-error-1.test"
             } = get_event("plausible-ingestion-event-multiple-with-error-1.test")
    end

    defp get_event(domain) do
      Plausible.TestUtils.eventually(fn ->
        Plausible.Event.WriteBuffer.flush()

        event =
          Plausible.ClickhouseRepo.one(
            from e in Plausible.ClickhouseEvent, where: e.domain == ^domain
          )

        {!is_nil(event), event}
      end)
    end
  end
end
