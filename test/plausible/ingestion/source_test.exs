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
end
