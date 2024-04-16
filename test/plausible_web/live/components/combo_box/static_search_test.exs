defmodule PlausibleWeb.Live.Components.ComboBox.StaticSearchTest do
  use ExUnit.Case, async: true

  alias PlausibleWeb.Live.Components.ComboBox.StaticSearch

  describe "autosuggest algorithm" do
    test "favours exact match" do
      options = fake_options(["yellow", "hello", "cruel hello world"])

      assert [{_, "hello"}, {_, "cruel hello world"}, {_, "yellow"}] =
               StaticSearch.suggest("hello", options)
    end

    test "skips entries shorter than input" do
      options = fake_options(["yellow", "hello", "cruel hello world"])

      assert [{_, "cruel hello world"}] = StaticSearch.suggest("cruel hello", options)
    end

    test "favours similarity" do
      options = fake_options(["melon", "hello", "yellow"])
      assert [{_, "hello"}, {_, "yellow"}, {_, "melon"}] = StaticSearch.suggest("hell", options)
    end

    test "allows fuzzy matching" do
      options = fake_options(["/url/0xC0FFEE", "/url/0xDEADBEEF", "/url/other"])
      assert [{_, "/url/0xC0FFEE"}] = StaticSearch.suggest("0x FF", options)
    end

    test "filters out bad matches" do
      options = fake_options(["OS", "Version", "Logged In"])
      assert [] = StaticSearch.suggest("cow", options)
    end

    test "uses custom to_string/1 function" do
      options = fake_options([%{key: "OS"}, %{key: "Version"}, %{key: "Logged In"}])
      assert [{_, %{key: "Version"}}] = StaticSearch.suggest("vers", options, to_string: & &1.key)
    end

    test "accepts custom jaro distance threshold" do
      options = fake_options(["Joanna", "Joel", "John"])
      assert [_, _, _] = StaticSearch.suggest("Joa", options, weight_threshold: 0.5)
      assert [{_, "Joanna"}] = StaticSearch.suggest("Joa", options, weight_threshold: 0.9)
    end
  end

  defp fake_options(option_names) do
    option_names
    |> Enum.shuffle()
    |> Enum.with_index(fn element, index -> {index, element} end)
  end
end
