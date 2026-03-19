defmodule Plausible.UAInspectorTest do
  use ExUnit.Case, async: true

  # Regression tests for https://github.com/elixir-inspector/ua_inspector/issues/37
  # Versions with leading zeros (e.g. "115.0.5765.05") caused Version.InvalidVersionError
  @version_parsing_cases [
    {
      ~s|Mozilla/5.0 (Linux; arm_64; Android 10; Mi Note 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.5765.05 Mobile Safari/537.36|,
      {"Chrome Mobile", "115.0.5765.05"}
    },
    {
      ~s|Mozilla/5.0 (Macintosh; Intel Mac OS X 13_2_1) AppleWebKit/537.3666 (KHTML, like Gecko) Chrome/110.0.0.0.0 Safari/537.3666|,
      {"Chrome", "110.0.0.0.0"}
    },
    {
      ~s|Mozilla/5.0 (Linux; Android 9; SM-G960F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/76.0.3809.089 Mobile Safari/537.36|,
      {"Chrome Mobile", "76.0.3809.089"}
    },
    {
      ~s|Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36|,
      {"Chrome", "120.0.0.0"}
    }
  ]

  for {ua, {expected_name, expected_version}} <- @version_parsing_cases do
    test "parses #{expected_name}/#{expected_version} without crashing" do
      result = UAInspector.parse(unquote(ua))

      assert %UAInspector.Result{} = result
      assert result.client.name == unquote(expected_name)
      assert result.client.version == unquote(expected_version)
    end
  end
end
