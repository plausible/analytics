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
    %{referrer_source: "Google", click_id_param: "gclid", expected: "Paid Search"},
    %{referrer_source: "DuckDuckGo", click_id_param: "gclid", expected: "Organic Search"},
    %{referrer_source: "Bing", click_id_param: "msclkid", expected: "Paid Search"},
    %{referrer_source: "DuckDuckGo", click_id_param: "msclkid", expected: "Organic Search"},
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
    %{referrer_source: "othersite.com", expected: "Referral"},
    %{referrer_source: "Threads", utm_source: "threads", expected: "Organic Social"},
    %{referrer_source: "Instagram", utm_source: "ig", expected: "Organic Social"},
    %{referrer_source: "Youtube", utm_source: "yt", expected: "Organic Video"},
    %{referrer_source: "Youtube", utm_source: "yt-ads", expected: "Paid Video"},
    %{referrer_source: "Facebook", utm_source: "fb", expected: "Organic Social"},
    %{referrer_source: "Facebook", utm_source: "fb-ads", expected: "Paid Social"},
    %{referrer_source: "Facebook", utm_source: "fbad", expected: "Paid Social"},
    %{referrer_source: "Facebook", utm_source: "facebook-ads", expected: "Paid Social"},
    %{referrer_source: "Reddit", utm_source: "Reddit-ads", expected: "Paid Social"},
    %{referrer_source: "Google", utm_source: "google_ads", expected: "Paid Search"},
    %{referrer_source: "Google", utm_source: "Google-ads", expected: "Paid Search"},
    %{referrer_source: "Google", utm_source: "Adwords", expected: "Paid Search"},
    %{referrer_source: "Twitter", utm_source: "twitter-ads", expected: "Paid Social"},
    %{referrer_source: "Reddit", expected: "Organic Social"},
    %{referrer_source: "Perplexity", expected: "Organic Search"},
    %{referrer_source: "Microsoft Teams", expected: "Organic Social"},
    %{referrer_source: "Wikipedia", expected: "Referral"},
    %{referrer_source: "Bing", expected: "Organic Search"},
    %{referrer_source: "Brave", expected: "Organic Search"},
    %{referrer_source: "Yandex", expected: "Organic Search"},
    %{referrer_source: "Discord", expected: "Organic Social"},
    %{referrer_source: "Baidu", expected: "Organic Search"},
    %{referrer_source: "Telegram", expected: "Organic Social"},
    %{referrer_source: "Sogou", expected: "Organic Search"},
    %{referrer_source: "Linktree", expected: "Referral"},
    %{referrer_source: "Linktree", utm_source: "linktree", expected: "Referral"},
    %{referrer_source: "Hacker News", expected: "Organic Social"},
    %{referrer_source: "Yahoo!", expected: "Organic Search"},
    %{referrer_source: "Gmail", expected: "Email"},
    %{referrer_source: "Newsletter-UK", utm_source: "Newsletter-UK", expected: "Email"},
    %{referrer_source: "temu.com", expected: "Organic Shopping"},
    %{referrer_source: "Telegram", utm_source: "Telegram", expected: "Organic Social"},
    %{referrer_source: "chatgpt.com", expected: "Organic Search"},
    %{referrer_source: "Slack", expected: "Organic Social"},
    %{referrer_source: "producthunt", expected: "Organic Social"},
    %{referrer_source: "GitHub", expected: "Organic Social"},
    %{referrer_source: "steamcommunity.com", expected: "Organic Social"},
    %{referrer_source: "Vkontakte", expected: "Organic Social"},
    %{referrer_source: "Threads", expected: "Organic Social"},
    %{referrer_source: "Ecosia", expected: "Organic Search"},
    %{
      referrer_source: "Google",
      utm_medium: "display",
      click_id_param: "123identifier",
      expected: "Display"
    }
  ]

  for {test_data, index} <- Enum.with_index(@static_tests, 1) do
    @tag test_data: test_data
    test "static test #{index} - #{Jason.encode!(test_data)}", %{test_data: test_data} do
      assert reference_channel(test_data) == test_data.expected
      assert clickhouse_channel(test_data) == test_data.expected
    end
  end

  def reference_channel(test_data) do
    Plausible.Ingestion.Acquisition.get_channel(
      test_data[:referrer_source],
      test_data[:utm_medium],
      test_data[:utm_campaign],
      test_data[:utm_source],
      test_data[:click_id_param]
    )
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
          test_data[:click_id_param] || ""
        ]
      )

    channel
  end
end
