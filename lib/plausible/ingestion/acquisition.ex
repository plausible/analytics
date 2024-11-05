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

  def get_channel(request, source) do
    source = source && String.downcase(source)

    cond do
      cross_network?(request) -> "Cross-network"
      paid_shopping?(request, source) -> "Paid Shopping"
      paid_search?(request, source) -> "Paid Search"
      paid_social?(request, source) -> "Paid Social"
      paid_video?(request, source) -> "Paid Video"
      display?(request) -> "Display"
      paid_other?(request) -> "Paid Other"
      organic_shopping?(request, source) -> "Organic Shopping"
      organic_social?(request, source) -> "Organic Social"
      organic_video?(request, source) -> "Organic Video"
      search_source?(source) -> "Organic Search"
      email?(request, source) -> "Email"
      affiliates?(request) -> "Affiliates"
      audio?(request) -> "Audio"
      sms?(request) -> "SMS"
      mobile_push_notifications?(request, source) -> "Mobile Push Notifications"
      referral?(request, source) -> "Referral"
      true -> "Direct"
    end
  end

  defp cross_network?(request) do
    String.contains?(query_param(request, "utm_campaign"), "cross-network")
  end

  defp paid_shopping?(request, source) do
    (shopping_source?(source) or shopping_campaign?(request)) and paid_medium?(request)
  end

  defp paid_search?(request, source) do
    (search_source?(source) and paid_medium?(request)) or
      (search_source?(source) and paid_source?(request)) or
      (source == "google" and !!request.query_params["gclid"]) or
      (source == "bing" and !!request.query_params["msclkid"])
  end

  defp paid_social?(request, source) do
    (social_source?(source) and paid_medium?(request)) or
      (social_source?(source) and paid_source?(request))
  end

  defp paid_video?(request, source) do
    (video_source?(source) and paid_medium?(request)) or
      (video_source?(source) and paid_source?(request))
  end

  defp display?(request) do
    query_param(request, "utm_medium") in [
      "display",
      "banner",
      "expandable",
      "interstitial",
      "cpm"
    ]
  end

  defp paid_other?(request) do
    paid_medium?(request)
  end

  defp organic_shopping?(request, source) do
    shopping_source?(source) or shopping_campaign?(request)
  end

  defp organic_social?(request, source) do
    social_source?(source) or
      query_param(request, "utm_medium") in [
        "social",
        "social-network",
        "social-media",
        "sm",
        "social network",
        "social media"
      ]
  end

  defp organic_video?(request, source) do
    video_source?(source) or String.contains?(query_param(request, "utm_medium"), "video")
  end

  defp referral?(request, source) do
    query_param(request, "utm_medium") in ["referral", "app", "link"] or
      (source || "") != ""
  end

  @email_tags ["email", "e-mail", "e_mail", "e mail", "newsletter"]
  defp email?(request, source) do
    email_source?(source) or
      String.contains?(query_param(request, "utm_source"), @email_tags) or
      String.contains?(query_param(request, "utm_medium"), @email_tags)
  end

  defp affiliates?(request) do
    query_param(request, "utm_medium") == "affiliate"
  end

  defp audio?(request) do
    query_param(request, "utm_medium") == "audio"
  end

  defp sms?(request) do
    query_param(request, "utm_source") == "sms" or
      query_param(request, "utm_medium") == "sms"
  end

  defp mobile_push_notifications?(request, source) do
    medium = query_param(request, "utm_medium")

    String.ends_with?(medium, "push") or
      String.contains?(medium, ["mobile", "notification"]) or
      source == "firebase"
  end

  defp shopping_source?(nil), do: false

  defp shopping_source?(source) do
    @source_categories[source] == "SOURCE_CATEGORY_SHOPPING"
  end

  defp search_source?(nil), do: false

  defp search_source?(source) do
    @source_categories[source] == "SOURCE_CATEGORY_SEARCH"
  end

  defp social_source?(nil), do: false

  defp social_source?(source) do
    @source_categories[source] == "SOURCE_CATEGORY_SOCIAL"
  end

  defp video_source?(nil), do: false

  defp video_source?(source) do
    @source_categories[source] == "SOURCE_CATEGORY_VIDEO"
  end

  defp email_source?(nil), do: false

  defp email_source?(source) do
    @source_categories[source] == "SOURCE_CATEGORY_EMAIL"
  end

  defp shopping_campaign?(request) do
    campaign_name = query_param(request, "utm_campaign")
    Regex.match?(~r/^(.*(([^a-df-z]|^)shop|shopping).*)$/, campaign_name)
  end

  defp paid_medium?(request) do
    medium = query_param(request, "utm_medium")
    Regex.match?(~r/^(.*cp.*|ppc|retargeting|paid.*)$/, medium)
  end

  defp paid_source?(request) do
    query_param(request, "utm_source")
    |> Plausible.Ingestion.Source.paid_source?()
  end

  defp query_param(request, name) do
    String.downcase(request.query_params[name] || "")
  end
end
