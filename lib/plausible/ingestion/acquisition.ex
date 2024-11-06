defmodule Plausible.Ingestion.Acquisition do
  @moduledoc """
  This module is responsible for figuring out acquisition channel from event referrer_source.

  Acquisition channel is the marketing channel where people come from and convert and help
  users to understand and improve their marketing flow.

  Note it uses priv/ga4-source-categories.csv as a source, which comes from https://support.google.com/analytics/answer/9756891?hl=en.

  Notable differences from GA4 that have been implemented just for Plausible:
  1. The @custom_source_categories module attribute contains a list of custom source categories that we have manually
  added based on our own judgement and user feedback. For example we treat AI tools (ChatGPT, Perplexity) as search engines.
  2. Google is in a privileged position to analyze paid traffic from within their own network. The biggest use-case is auto-tagged adwords campaigns.
  We do our best by categorizing as paid search when source is Google and the url has `gclid` parameter. Same for source Bing and `msclkid` url parameter.
  3. The @paid_sources module attribute in Plausible.Ingestion.Source contains a list of utm_sources that we will automatically categorize as paid traffic
  regardless of the medium. Examples are `yt-ads`, `facebook_ad`, `adwords`, etc. See also: Plausible.Ingestion.Source.paid_source?/1
  """

  @external_resource "priv/ga4-source-categories.csv"
  @custom_source_categories [
    {"hacker news", "SOURCE_CATEGORY_SOCIAL"},
    {"yahoo!", "SOURCE_CATEGORY_SEARCH"},
    {"gmail", "SOURCE_CATEGORY_EMAIL"},
    {"telegram", "SOURCE_CATEGORY_SOCIAL"},
    {"slack", "SOURCE_CATEGORY_SOCIAL"},
    {"producthunt", "SOURCE_CATEGORY_SOCIAL"},
    {"github", "SOURCE_CATEGORY_SOCIAL"},
    {"steamcommunity.com", "SOURCE_CATEGORY_SOCIAL"},
    {"statics.teams.cdn.office.net", "SOURCE_CATEGORY_SOCIAL"},
    {"vkontakte", "SOURCE_CATEGORY_SOCIAL"},
    {"threads", "SOURCE_CATEGORY_SOCIAL"},
    {"ecosia", "SOURCE_CATEGORY_SEARCH"},
    {"perplexity", "SOURCE_CATEGORY_SEARCH"},
    {"brave", "SOURCE_CATEGORY_SEARCH"},
    {"chatgpt.com", "SOURCE_CATEGORY_SEARCH"},
    {"temu.com", "SOURCE_CATEGORY_SHOPPING"},
    {"discord", "SOURCE_CATEGORY_SOCIAL"},
    {"sogou", "SOURCE_CATEGORY_SEARCH"},
    {"microsoft teams", "SOURCE_CATEGORY_SOCIAL"}
  ]
  @source_categories Application.app_dir(:plausible, "priv/ga4-source-categories.csv")
                     |> File.read!()
                     |> NimbleCSV.RFC4180.parse_string(skip_headers: false)
                     |> Enum.map(fn [source, category] -> {source, category} end)
                     |> then(&(@custom_source_categories ++ &1))
                     |> Enum.into(%{})

  def source_categories(), do: @source_categories

  def get_channel(source, utm_medium, utm_campaign, utm_source, click_id_param) do
    get_channel_lowered(
      String.downcase(source || ""),
      String.downcase(utm_medium || ""),
      String.downcase(utm_campaign || ""),
      String.downcase(utm_source || ""),
      click_id_param
    )
  end

  defp get_channel_lowered(source, utm_medium, utm_campaign, utm_source, click_id_param) do
    cond do
      cross_network?(utm_campaign) -> "Cross-network"
      paid_shopping?(source, utm_campaign, utm_medium) -> "Paid Shopping"
      paid_search?(source, utm_medium, utm_source, click_id_param) -> "Paid Search"
      paid_social?(source, utm_medium, utm_source) -> "Paid Social"
      paid_video?(source, utm_medium, utm_source) -> "Paid Video"
      display?(utm_medium) -> "Display"
      paid_other?(utm_medium) -> "Paid Other"
      organic_shopping?(source, utm_campaign) -> "Organic Shopping"
      organic_social?(source, utm_medium) -> "Organic Social"
      organic_video?(source, utm_medium) -> "Organic Video"
      search_source?(source) -> "Organic Search"
      email?(source, utm_source, utm_medium) -> "Email"
      affiliates?(utm_medium) -> "Affiliates"
      audio?(utm_medium) -> "Audio"
      sms?(utm_source, utm_medium) -> "SMS"
      mobile_push_notifications?(source, utm_medium) -> "Mobile Push Notifications"
      referral?(source, utm_medium) -> "Referral"
      true -> "Direct"
    end
  end

  defp cross_network?(utm_campaign) do
    String.contains?(utm_campaign, "cross-network")
  end

  defp paid_shopping?(source, utm_campaign, utm_medium) do
    (shopping_source?(source) or shopping_campaign?(utm_campaign)) and paid_medium?(utm_medium)
  end

  defp paid_search?(source, utm_medium, utm_source, click_id_param) do
    (search_source?(source) and paid_medium?(utm_medium)) or
      (search_source?(source) and paid_source?(utm_source)) or
      (source == "google" and click_id_param == "gclid") or
      (source == "bing" and click_id_param == "msclkid")
  end

  defp paid_social?(source, utm_medium, utm_source) do
    (social_source?(source) and paid_medium?(utm_medium)) or
      (social_source?(source) and paid_source?(utm_source))
  end

  defp paid_video?(source, utm_medium, utm_source) do
    (video_source?(source) and paid_medium?(utm_medium)) or
      (video_source?(source) and paid_source?(utm_source))
  end

  defp display?(utm_medium) do
    utm_medium in [
      "display",
      "banner",
      "expandable",
      "interstitial",
      "cpm"
    ]
  end

  defp paid_other?(utm_medium) do
    paid_medium?(utm_medium)
  end

  defp organic_shopping?(source, utm_campaign) do
    shopping_source?(source) or shopping_campaign?(utm_campaign)
  end

  defp organic_social?(source, utm_medium) do
    social_source?(source) or
      utm_medium in [
        "social",
        "social-network",
        "social-media",
        "sm",
        "social network",
        "social media"
      ]
  end

  defp organic_video?(source, utm_medium) do
    video_source?(source) or String.contains?(utm_medium, "video")
  end

  defp referral?(source, utm_medium) do
    utm_medium in ["referral", "app", "link"] or source !== ""
  end

  @email_tags ["email", "e-mail", "e_mail", "e mail", "newsletter"]
  defp email?(source, utm_source, utm_medium) do
    email_source?(source) or
      String.contains?(utm_source, @email_tags) or
      String.contains?(utm_medium, @email_tags)
  end

  defp affiliates?(utm_medium) do
    utm_medium == "affiliate"
  end

  defp audio?(utm_medium) do
    utm_medium == "audio"
  end

  defp sms?(utm_source, utm_medium) do
    utm_source == "sms" or utm_medium == "sms"
  end

  defp mobile_push_notifications?(source, utm_medium) do
    String.ends_with?(utm_medium, "push") or
      String.contains?(utm_medium, ["mobile", "notification"]) or
      source == "firebase"
  end

  defp shopping_source?(source) do
    @source_categories[source] == "SOURCE_CATEGORY_SHOPPING"
  end

  defp search_source?(source) do
    @source_categories[source] == "SOURCE_CATEGORY_SEARCH"
  end

  defp social_source?(source) do
    @source_categories[source] == "SOURCE_CATEGORY_SOCIAL"
  end

  defp video_source?(source) do
    @source_categories[source] == "SOURCE_CATEGORY_VIDEO"
  end

  defp email_source?(source) do
    @source_categories[source] == "SOURCE_CATEGORY_EMAIL"
  end

  defp shopping_campaign?(utm_campaign) do
    Regex.match?(~r/^(.*(([^a-df-z]|^)shop|shopping).*)$/, utm_campaign)
  end

  defp paid_medium?(utm_medium) do
    Regex.match?(~r/^(.*cp.*|ppc|retargeting|paid.*)$/, utm_medium)
  end

  defp paid_source?(utm_source) do
    Plausible.Ingestion.Source.paid_source?(utm_source)
  end
end
