defmodule Plausible.Ingestion.Acquisition do
  @moduledoc """
  This module is responsible for figuring out aquisition channel from event referrer_source.

  Acquisition channel is the marketing channel where people come from and convert and help
  users to understand and improve their marketing flow.

  Note it uses priv/ga4-source-categories.csv as a source, which comes from XXX.
  """
  @external_resource "priv/ga4-source-categories.csv"
  @mapping_overrides [
    {"fb", "Facebook"},
    {"ig", "Instagram"},
    {"perplexity", "Perplexity"},
    {"linktree", "Linktree"}
  ]
  @custom_source_categories [
    {"hacker news", "SOURCE_CATEGORY_SOCIAL"},
    {"yahoo!", "SOURCE_CATEGORY_SEARCH"},
    {"gmail", "SOURCE_CATEGORY_EMAIL"},
    {"telegram", "SOURCE_CATEGORY_SOCIAL"},
    {"slack", "SOURCE_CATEGORY_SOCIAL"},
    {"producthunt", "SOURCE_CATEGORY_SOCIAL"},
    {"github", "SOURCE_CATEGORY_SOCIAL"},
    {"steamcommunity.com", "SOURCE_CATEGORY_SOCIAL"},
    # codespell:ignore
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

  def init() do
    :ets.new(__MODULE__, [
      :named_table,
      :set,
      :public,
      {:read_concurrency, true}
    ])

    [{"referers.yml", map}] = RefInspector.Database.list(:default)

    Enum.each(map, fn {_, entries} ->
      Enum.each(entries, fn {_, _, _, _, _, _, name} ->
        :ets.insert(__MODULE__, {String.downcase(name), name})
      end)
    end)

    Enum.each(@mapping_overrides, fn override ->
      :ets.insert(__MODULE__, override)
    end)
  end

  def find_mapping(source) do
    case :ets.lookup(__MODULE__, source) do
      [{_, name}] -> name
      _ -> source
    end
  end

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
      (source == "google" and !!request.query_params["gclid"]) or
      (source == "bing" and !!request.query_params["msclkid"])
  end

  defp paid_social?(request, source) do
    social_source?(source) and paid_medium?(request)
  end

  defp paid_video?(request, source) do
    video_source?(source) and paid_medium?(request)
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
      !!source
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

  # # Helper functions for source and medium checks
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
    Regex.match?(~r/^(.*(([^a-df-z]|^)shop|shopping).*)$/, campaign_name || "")
  end

  defp paid_medium?(request) do
    medium = query_param(request, "utm_medium")
    Regex.match?(~r/^(.*cp.*|ppc|retargeting|paid.*)$/, medium)
  end

  defp query_param(request, name) do
    String.downcase(request.query_params[name] || "")
  end
end
