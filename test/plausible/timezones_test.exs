defmodule Plausible.TimezonesTest do
  use ExUnit.Case, async: true

  test "options/0 returns a list of timezones" do
    options = Plausible.Timezones.options()
    refute Enum.empty?(options)

    gmt12 = Enum.find(options, &(&1[:value] == "Etc/GMT+12"))
    assert [key: "(GMT-12:00) Etc/GMT+12", value: "Etc/GMT+12", offset: 720] = gmt12

    hawaii = Enum.find(options, &(&1[:value] == "US/Hawaii"))
    assert [key: "(GMT-10:00) US/Hawaii", value: "US/Hawaii", offset: 600] = hawaii
  end
end
