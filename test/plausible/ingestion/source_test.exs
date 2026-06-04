defmodule Plausible.Ingestion.SourceTest do
  use ExUnit.Case, async: true

  alias Plausible.Ingestion.{Source, Request}
  @base_request %Request{uri: URI.parse("https://plausible.io")}

  test "known referrer from RefInspector" do
    assert Source.resolve(%{@base_request | referrer: "https://google.com"}) == "Google"
  end

  test "known source from RefInspector supplied as downcased utm_source by user" do
    assert Source.resolve(%{@base_request | query_params: %{"utm_source" => "google"}}) ==
             "Google"
  end

  test "known source from RefInspector supplied as uppercased utm_source by user" do
    assert Source.resolve(%{@base_request | query_params: %{"utm_source" => "GOOGLE"}}) ==
             "Google"
  end

  test "known referrer from custom_sources.json" do
    assert Source.resolve(%{@base_request | referrer: "https://en.m.wikipedia.org"}) ==
             "Wikipedia"
  end

  test "known source from custom_sources.json supplied as downcased utm_source by user" do
    assert Source.resolve(%{@base_request | query_params: %{"utm_source" => "wikipedia"}}) ==
             "Wikipedia"
  end

  test "known utm_source from custom_sources.json" do
    assert Source.resolve(%{@base_request | query_params: %{"utm_source" => "ig"}}) == "Instagram"
  end

  test "unknown source, it is just stored as the domain name" do
    assert Source.resolve(%{@base_request | referrer: "https://www.markosaric.com"}) ==
             "markosaric.com"
  end

  test "bsky.app referrer is Bluesky" do
    assert Source.resolve(%{@base_request | referrer: "https://bsky.app"}) == "Bluesky"
  end

  test "go.bsky.app referrer is Bluesky" do
    assert Source.resolve(%{@base_request | referrer: "https://go.bsky.app"}) == "Bluesky"
  end

  test "mastodon.social referrer is Mastodon" do
    assert Source.resolve(%{@base_request | referrer: "https://mastodon.social"}) == "Mastodon"
  end

  test "fosstodon.org referrer is Mastodon" do
    assert Source.resolve(%{@base_request | referrer: "https://fosstodon.org"}) == "Mastodon"
  end

  test "gemini.google.com referrer is Google Gemini, not Google" do
    assert Source.resolve(%{@base_request | referrer: "https://gemini.google.com"}) ==
             "Google Gemini"
  end

  test "chatgpt.com referrer is ChatGPT" do
    assert Source.resolve(%{@base_request | referrer: "https://chatgpt.com"}) == "ChatGPT"
  end

  test "chat.openai.com referrer is ChatGPT" do
    assert Source.resolve(%{@base_request | referrer: "https://chat.openai.com"}) == "ChatGPT"
  end

  test "claude.ai referrer is Claude" do
    assert Source.resolve(%{@base_request | referrer: "https://claude.ai"}) == "Claude"
  end

  test "phind.com referrer is Phind" do
    assert Source.resolve(%{@base_request | referrer: "https://phind.com"}) == "Phind"
  end

  test "copilot.microsoft.com referrer is Microsoft Copilot" do
    assert Source.resolve(%{@base_request | referrer: "https://copilot.microsoft.com"}) ==
             "Microsoft Copilot"
  end

  test "copilot.com referrer is Microsoft Copilot" do
    assert Source.resolve(%{@base_request | referrer: "https://copilot.com"}) ==
             "Microsoft Copilot"
  end

  test "x.com referrer is X (Twitter)" do
    assert Source.resolve(%{@base_request | referrer: "https://x.com"}) == "X (Twitter)"
  end

  test "kagi.com referrer is Kagi" do
    assert Source.resolve(%{@base_request | referrer: "https://kagi.com"}) == "Kagi"
  end

  test "l.threads.com referrer is Threads" do
    assert Source.resolve(%{@base_request | referrer: "https://l.threads.com"}) == "Threads"
  end

  test "pplx.ai referrer is Perplexity" do
    assert Source.resolve(%{@base_request | referrer: "https://pplx.ai"}) == "Perplexity"
  end

  test "officeapps.live.com and its subdomains are Microsoft 365" do
    for referrer <- [
          "https://officeapps.live.com",
          "https://cac-excel.officeapps.live.com",
          "https://euc-excel.officeapps.live.com",
          "https://ukc-word-edit.officeapps.live.com"
        ] do
      assert Source.resolve(%{@base_request | referrer: referrer}) == "Microsoft 365"
    end
  end

  test "a host that only looks like the officeapps suffix is not Microsoft 365" do
    assert Source.resolve(%{@base_request | referrer: "https://notofficeapps.live.com"}) ==
             "notofficeapps.live.com"
  end

  test "any wikipedia.org subdomain is Wikipedia (including unlisted language editions)" do
    for referrer <- [
          "https://wikipedia.org",
          "https://www.wikipedia.org",
          "https://en.wikipedia.org",
          "https://en.m.wikipedia.org",
          "https://zu.wikipedia.org"
        ] do
      assert Source.resolve(%{@base_request | referrer: referrer}) == "Wikipedia"
    end
  end

  test "a host that only looks like the wikipedia suffix is not Wikipedia" do
    assert Source.resolve(%{@base_request | referrer: "https://notwikipedia.org"}) ==
             "notwikipedia.org"
  end

  test "RefInspector-resolved aliases are normalized (t.co referrer is 'X (Twitter)')" do
    # t.co is a Twitter domain known to RefInspector but not in custom_sources.json,
    # so it exercises the RefInspector branch and canonical mapping ('Twitter' to 'X (Twitter)').
    assert Source.resolve(%{@base_request | referrer: "https://t.co"}) == "X (Twitter)"
  end

  test "from_referrer normalizes RefInspector aliases like resolve does" do
    # The importer calls from_referrer directly, so it must apply the same aliasing
    # as live ingestion (previously it returned the raw "Twitter").
    assert Source.from_referrer("https://t.co") == "X (Twitter)"
    assert Source.from_referrer("https://gemini.google.com") == "Google Gemini"
    assert Source.from_referrer("https://www.markosaric.com") == "markosaric.com"
  end
end
