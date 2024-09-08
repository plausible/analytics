defmodule Plausible.TimezonesTest do
  use ExUnit.Case, async: true

  import Plausible.Timezones

  test "options/0 returns a list of timezones" do
    options = options()
    refute Enum.empty?(options)

    gmt12 = Enum.find(options, &(&1[:value] == "Etc/GMT+12"))
    assert [key: "(GMT-12:00) Etc/GMT+12", value: "Etc/GMT+12", offset: 720] = gmt12

    hawaii = Enum.find(options, &(&1[:value] == "US/Hawaii"))
    assert [key: "(GMT-10:00) US/Hawaii", value: "US/Hawaii", offset: 600] = hawaii
  end

  test "options/0 does not fail during time changes" do
    options = options(~N[2021-10-03 02:31:07])
    refute Enum.empty?(options)
  end

  test "to_date_in_timezone/1" do
    assert to_date_in_timezone(~D[2021-01-03], "Etc/UTC") == ~D[2021-01-03]
    assert to_date_in_timezone(~U[2015-01-13 13:00:07Z], "Etc/UTC") == ~D[2015-01-13]
    assert to_date_in_timezone(~N[2015-01-13 13:00:07], "Etc/UTC") == ~D[2015-01-13]
    assert to_date_in_timezone(~N[2015-01-13 19:00:07], "Etc/GMT+12") == ~D[2015-01-13]
  end

  test "to_datetime_in_timezone/1" do
    assert to_datetime_in_timezone(~D[2021-01-03], "Etc/UTC") == ~U[2021-01-03 00:00:00Z]
    assert to_datetime_in_timezone(~N[2015-01-13 13:00:07], "Etc/UTC") == ~U[2015-01-13 13:00:07Z]

    assert to_datetime_in_timezone(~N[2015-01-13 19:00:07], "Etc/GMT+12") ==
             %DateTime{
               microsecond: {0, 0},
               second: 7,
               calendar: Calendar.ISO,
               month: 1,
               day: 13,
               year: 2015,
               minute: 0,
               hour: 7,
               time_zone: "Etc/GMT+12",
               zone_abbr: "-12",
               utc_offset: -43_200,
               std_offset: 0
             }

    assert to_datetime_in_timezone(~N[2016-03-27 02:30:00], "Europe/Copenhagen") == %DateTime{
             microsecond: {0, 0},
             second: 0,
             calendar: Calendar.ISO,
             month: 3,
             day: 27,
             year: 2016,
             minute: 30,
             hour: 4,
             time_zone: "Europe/Copenhagen",
             zone_abbr: "CEST",
             utc_offset: 3600,
             std_offset: 3600
           }
  end
end
