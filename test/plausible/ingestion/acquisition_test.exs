defmodule Plausible.Ingestion.AcquisitionTest do
  use Plausible.DataCase

  setup_all do
    Plausible.DataMigration.AcquisitionChannel.run(quiet: true)
  end

  @static_tests [
    %{expected: "Direct"},
    %{utm_campaign: "cross-network", expected: "Cross-network"},
    %{utm_campaign: "shopping", utm_medium: "paid", expected: "Paid Shopping"},
    %{referrer_source: "shopify.com", utm_medium: "paid", expected: "Paid Shopping"},
    %{
      referrer_source: "shopify",
      utm_source: "shopify",
      utm_medium: "paid",
      expected: "Paid Shopping"
    },
    %{referrer_source: "DuckDuckGo", utm_medium: "paid", expected: "Paid Search"},
    %{referrer_source: "Google", click_id_source: "Google", expected: "Paid Search"},
    %{referrer_source: "DuckDuckGo", click_id_source: "Google", expected: "Organic Search"},
    %{referrer_source: "Bing", click_id_source: "Bing", expected: "Paid Search"},
    %{referrer_source: "DuckDuckGo", click_id_source: "Bing", expected: "Organic Search"},
    %{
      referrer_source: "google",
      utm_source: "google",
      utm_medium: "paid",
      expected: "Paid Search"
    },
    %{referrer_source: "TikTok", utm_medium: "paid", expected: "Paid Social"},
    %{
      referrer_source: "tiktok",
      utm_source: "tiktok",
      utm_medium: "paid",
      expected: "Paid Social"
    },
    %{referrer_source: "Youtube", utm_medium: "paid", expected: "Paid Video"},
    %{
      referrer_source: "youtube",
      utm_source: "youtube",
      utm_medium: "paid",
      expected: "Paid Video"
    },
    %{utm_medium: "banner", expected: "Display"},
    %{utm_medium: "cpc", expected: "Paid Other"},
    %{referrer_source: "walmart.com", expected: "Organic Shopping"},
    %{referrer_source: "walmart", utm_source: "walmart", expected: "Organic Shopping"},
    %{utm_campaign: "shop", expected: "Organic Shopping"},
    %{referrer_source: "Facebook", expected: "Organic Social"},
    %{referrer_source: "twitter", utm_source: "twitter", expected: "Organic Social"},
    %{utm_medium: "social", expected: "Organic Social"},
    %{referrer_source: "Vimeo", expected: "Organic Video"},
    %{referrer_source: "vimeo", utm_source: "vimeo", expected: "Organic Video"},
    %{utm_medium: "video", expected: "Organic Video"},
    %{referrer_source: "DuckDuckGo", expected: "Organic Search"},
    %{referrer_source: "duckduckgo", utm_source: "duckduckgo", expected: "Organic Search"},
    %{utm_medium: "referral", expected: "Referral"},
    %{referrer_source: "email", utm_source: "email", expected: "Email"},
    %{utm_medium: "email", expected: "Email"},
    %{utm_medium: "affiliate", expected: "Affiliates"},
    %{utm_medium: "audio", expected: "Audio"},
    %{referrer_source: "sms", utm_source: "sms", expected: "SMS"},
    %{utm_medium: "sms", expected: "SMS"},
    %{utm_medium: "app-push", expected: "Mobile Push Notifications"},
    %{utm_medium: "example-mobile", expected: "Mobile Push Notifications"},
    %{referrer_source: "othersite.com", expected: "Referral"}
  ]

  for {test_data, index} <- Enum.with_index(@static_tests, 1) do
    @tag test_data: test_data
    test "static test #{index} - #{Jason.encode!(test_data)}", %{test_data: test_data} do
      assert clickhouse_channel(test_data) == test_data.expected
    end
  end

  def clickhouse_channel(test_data) do
    %{rows: [[channel]]} =
      Plausible.IngestRepo.query!(
        "SELECT acquisition_channel({$0:String}, {$1:String}, {$2:String}, {$3:String}, {$4:String})",
        [
          test_data[:referrer_source] || "",
          test_data[:utm_medium] || "",
          test_data[:utm_campaign] || "",
          test_data[:utm_source] || "",
          test_data[:click_id_source] || ""
        ]
      )

    channel
  end
end
