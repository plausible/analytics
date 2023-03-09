defmodule Plausible.Stats.FiltersTest do
  use ExUnit.Case, async: true
  alias Plausible.Stats.{Query, Filters}

  def assert_parsed(filters, expected_output) do
    new_query =
      %Query{filters: filters}
      |> Filters.add_prefix()

    assert new_query.filters == expected_output
  end

  describe "adding prefix" do
    test "adds appropriate prefix to filter" do
      %{"page" => "/"}
      |> assert_parsed(%{"event:page" => {:is, "/"}})

      %{"goal" => "Signup"}
      |> assert_parsed(%{"event:goal" => {:is, :event, "Signup"}})

      %{"goal" => "Visit /blog"}
      |> assert_parsed(%{"event:goal" => {:is, :page, "/blog"}})

      %{"source" => "Google"}
      |> assert_parsed(%{"visit:source" => {:is, "Google"}})

      %{"referrer" => "cnn.com"}
      |> assert_parsed(%{"visit:referrer" => {:is, "cnn.com"}})

      %{"utm_medium" => "search"}
      |> assert_parsed(%{"visit:utm_medium" => {:is, "search"}})

      %{"utm_source" => "bing"}
      |> assert_parsed(%{"visit:utm_source" => {:is, "bing"}})

      %{"utm_content" => "content"}
      |> assert_parsed(%{"visit:utm_content" => {:is, "content"}})

      %{"utm_term" => "term"}
      |> assert_parsed(%{"visit:utm_term" => {:is, "term"}})

      %{"screen" => "Desktop"}
      |> assert_parsed(%{"visit:screen" => {:is, "Desktop"}})

      %{"browser" => "Opera"}
      |> assert_parsed(%{"visit:browser" => {:is, "Opera"}})

      %{"browser_version" => "10.1"}
      |> assert_parsed(%{"visit:browser_version" => {:is, "10.1"}})

      %{"os" => "Linux"}
      |> assert_parsed(%{"visit:os" => {:is, "Linux"}})

      %{"os_version" => "13.0"}
      |> assert_parsed(%{"visit:os_version" => {:is, "13.0"}})

      %{"country" => "EE"}
      |> assert_parsed(%{"visit:country" => {:is, "EE"}})

      %{"region" => "EE-12"}
      |> assert_parsed(%{"visit:region" => {:is, "EE-12"}})

      %{"city" => "123"}
      |> assert_parsed(%{"visit:city" => {:is, "123"}})

      %{"entry_page" => "/blog"}
      |> assert_parsed(%{"visit:entry_page" => {:is, "/blog"}})

      %{"exit_page" => "/blog"}
      |> assert_parsed(%{"visit:exit_page" => {:is, "/blog"}})

      %{"props" => %{"cta" => "Top"}}
      |> assert_parsed(%{"event:props:cta" => {:is, "Top"}})
    end
  end

  describe "is not filter type" do
    test "simple is not filter" do
      %{"page" => "!/"}
      |> assert_parsed(%{"event:page" => {:is_not, "/"}})

      %{"props" => %{"cta" => "!Top"}}
      |> assert_parsed(%{"event:props:cta" => {:is_not, "Top"}})
    end
  end

  describe "matches filter type" do
    test "can be used with `goal` or `page` filters" do
      %{"page" => "/blog/post-*"}
      |> assert_parsed(%{"event:page" => {:matches, "/blog/post-*"}})

      %{"goal" => "Visit /blog/post-*"}
      |> assert_parsed(%{"event:goal" => {:matches, :page, "/blog/post-*"}})
    end

    test "other filters default to `is` even when wildcard is present" do
      %{"country" => "Germa**"}
      |> assert_parsed(%{"visit:country" => {:is, "Germa**"}})
    end
  end

  describe "does_not_match filter type" do
    test "can be used with `page` filter" do
      %{"page" => "!/blog/post-*"}
      |> assert_parsed(%{"event:page" => {:does_not_match, "/blog/post-*"}})
    end

    test "other filters default to is_not even when wildcard is present" do
      %{"country" => "!Germa**"}
      |> assert_parsed(%{"visit:country" => {:is_not, "Germa**"}})
    end
  end

  describe "contains prefix filter type" do
    test "can be used with any filter" do
      %{"page" => "~/blog/post"}
      |> assert_parsed(%{"event:page" => {:matches, "**/blog/post**"}})

      %{"source" => "~facebook"}
      |> assert_parsed(%{"visit:source" => {:matches, "**facebook**"}})
    end
  end
end
