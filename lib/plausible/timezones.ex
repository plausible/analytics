defmodule Plausible.Timezones do
  @moduledoc "https://stackoverflow.com/a/52265733"

  @options [
    [key: "(GMT-12:00) International Date Line West", value: "Etc/GMT+12", offset: "720"],
    [key: "(GMT-11:00) Midway Island, Samoa", value: "Pacific/Midway", offset: "660"],
    [key: "(GMT-10:00) Hawaii", value: "Pacific/Honolulu", offset: "600"],
    [key: "(GMT-09:00) Alaska", value: "US/Alaska", offset: "540"],
    [key: "(GMT-08:00) Pacific Time (US & Canada)", value: "America/Los_Angeles", offset: "480"],
    [key: "(GMT-08:00) Tijuana, Baja California", value: "America/Tijuana"],
    [key: "(GMT-07:00) Arizona", value: "US/Arizona"],
    [key: "(GMT-07:00) Chihuahua, La Paz, Mazatlan", value: "America/Chihuahua"],
    [key: "(GMT-07:00) Mountain Time (US & Canada)", value: "US/Mountain", offset: "420"],
    [key: "(GMT-06:00) Central America", value: "America/Managua"],
    [key: "(GMT-06:00) Central Time (US & Canada)", value: "US/Central", offset: "360"],
    [key: "(GMT-06:00) Guadalajara, Mexico City, Monterrey", value: "America/Mexico_City"],
    [key: "(GMT-06:00) Saskatchewan", value: "Canada/Saskatchewan"],
    [key: "(GMT-05:00) Bogota, Lima, Quito, Rio Branco", value: "America/Bogota"],
    [key: "(GMT-05:00) Eastern Time (US & Canada)", value: "US/Eastern", offset: "300"],
    [key: "(GMT-05:00) Indiana (East)", value: "US/East-Indiana"],
    [key: "(GMT-04:00) Atlantic Time (Canada)", value: "Canada/Atlantic", offset: "240"],
    [key: "(GMT-04:00) Caracas, La Paz", value: "America/Caracas"],
    [key: "(GMT-04:00) Manaus", value: "America/Manaus"],
    [key: "(GMT-04:00) Santiago", value: "America/Santiago"],
    [key: "(GMT-03:30) Newfoundland", value: "Canada/Newfoundland"],
    [key: "(GMT-03:00) Brasilia", value: "America/Sao_Paulo", offset: "180"],
    [key: "(GMT-03:00) Buenos Aires, Georgetown", value: "America/Argentina/Buenos_Aires"],
    [key: "(GMT-03:00) Greenland", value: "America/Godthab"],
    [key: "(GMT-03:00) Montevideo", value: "America/Montevideo"],
    [key: "(GMT-02:00) Mid-Atlantic", value: "America/Noronha", offset: "120"],
    [key: "(GMT-01:00) Cape Verde Is.", value: "Atlantic/Cape_Verde", offset: "60"],
    [key: "(GMT-01:00) Azores", value: "Atlantic/Azores"],
    [key: "(GMT+00:00) Casablanca, Monrovia, Reykjavik", value: "Africa/Casablanca"],
    [
      key: "(GMT+00:00) Greenwich Mean Time : Dublin, Edinburgh, Lisbon, London",
      value: "Etc/Greenwich",
      offset: "0"
    ],
    [
      key: "(GMT+01:00) Amsterdam, Berlin, Bern, Rome, Stockholm, Vienna",
      value: "Europe/Amsterdam",
      offset: "-60"
    ],
    [
      key: "(GMT+01:00) Belgrade, Bratislava, Budapest, Ljubljana, Prague",
      value: "Europe/Belgrade"
    ],
    [key: "(GMT+01:00) Brussels, Copenhagen, Madrid, Paris", value: "Europe/Brussels"],
    [key: "(GMT+01:00) Sarajevo, Skopje, Warsaw, Zagreb", value: "Europe/Sarajevo"],
    [key: "(GMT+01:00) West Central Africa", value: "Africa/Lagos"],
    [key: "(GMT+02:00) Amman", value: "Asia/Amman"],
    [key: "(GMT+02:00) Athens, Bucharest, Istanbul", value: "Europe/Athens"],
    [key: "(GMT+02:00) Beirut", value: "Asia/Beirut"],
    [key: "(GMT+02:00) Cairo", value: "Africa/Cairo"],
    [key: "(GMT+02:00) Harare, Pretoria", value: "Africa/Harare"],
    [
      key: "(GMT+02:00) Helsinki, Kyiv, Riga, Sofia, Tallinn, Vilnius",
      value: "Europe/Helsinki",
      offset: "-120"
    ],
    [key: "(GMT+02:00) Jerusalem", value: "Asia/Jerusalem"],
    [key: "(GMT+02:00) Minsk", value: "Europe/Minsk"],
    [key: "(GMT+02:00) Windhoek", value: "Africa/Windhoek"],
    [key: "(GMT+03:00) Kuwait, Riyadh, Baghdad", value: "Asia/Kuwait"],
    [
      key: "(GMT+03:00) Moscow, St. Petersburg, Volgograd",
      value: "Europe/Moscow",
      offset: "-180"
    ],
    [key: "(GMT+03:00) Nairobi", value: "Africa/Nairobi"],
    [key: "(GMT+03:00) Tbilisi", value: "Asia/Tbilisi"],
    [key: "(GMT+03:30) Tehran", value: "Asia/Tehran", offset: "-210"],
    [key: "(GMT+04:00) Abu Dhabi, Muscat", value: "Asia/Muscat", offset: "-240"],
    [key: "(GMT+04:00) Baku", value: "Asia/Baku"],
    [key: "(GMT+04:00) Yerevan", value: "Asia/Yerevan"],
    [key: "(GMT+04:30) Kabul", value: "Asia/Kabul", offset: "-270"],
    [key: "(GMT+05:00) Yekaterinburg", value: "Asia/Yekaterinburg"],
    [key: "(GMT+05:00) Islamabad, Karachi, Tashkent", value: "Asia/Karachi", offset: "-300"],
    [
      key: "(GMT+05:30) Chennai, Kolkata, Mumbai, New Delhi",
      value: "Asia/Calcutta",
      offset: "-330"
    ],
    [key: "(GMT+05:30) Sri Jayawardenapura", value: "Asia/Calcutta"],
    [key: "(GMT+05:45) Kathmandu", value: "Asia/Katmandu", offset: "-345"],
    [key: "(GMT+06:00) Almaty, Novosibirsk", value: "Asia/Almaty", offset: "-360"],
    [key: "(GMT+06:00) Astana, Dhaka", value: "Asia/Dhaka"],
    [key: "(GMT+06:30) Yangon (Rangoon)", value: "Asia/Rangoon", offset: "-390"],
    [key: "(GMT+07:00) Bangkok, Hanoi, Jakarta", value: "Asia/Bangkok", offset: "-420"],
    [key: "(GMT+07:00) Krasnoyarsk", value: "Asia/Krasnoyarsk"],
    [
      key: "(GMT+08:00) Beijing, Chongqing, Hong Kong, Urumqi",
      value: "Asia/Hong_Kong",
      offset: "-480"
    ],
    [key: "(GMT+08:00) Kuala Lumpur, Singapore", value: "Asia/Kuala_Lumpur"],
    [key: "(GMT+08:00) Irkutsk, Ulaan Bataar", value: "Asia/Irkutsk"],
    [key: "(GMT+08:00) Perth", value: "Australia/Perth"],
    [key: "(GMT+08:00) Taipei", value: "Asia/Taipei"],
    [key: "(GMT+09:00) Osaka, Sapporo, Tokyo", value: "Asia/Tokyo", offset: "-540"],
    [key: "(GMT+09:00) Seoul", value: "Asia/Seoul"],
    [key: "(GMT+09:00) Yakutsk", value: "Asia/Yakutsk"],
    [key: "(GMT+09:30) Adelaide", value: "Australia/Adelaide", offset: "-570"],
    [key: "(GMT+09:30) Darwin", value: "Australia/Darwin"],
    [key: "(GMT+10:00) Brisbane", value: "Australia/Brisbane", offset: "-600"],
    [key: "(GMT+10:00) Canberra, Melbourne, Sydney", value: "Australia/Canberra"],
    [key: "(GMT+10:00) Hobart", value: "Australia/Hobart"],
    [key: "(GMT+10:00) Guam, Port Moresby", value: "Pacific/Guam"],
    [key: "(GMT+10:00) Vladivostok", value: "Asia/Vladivostok"],
    [
      key: "(GMT+11:00) Magadan, Solomon Is., New Caledonia",
      value: "Asia/Magadan",
      offset: "-660"
    ],
    [key: "(GMT+12:00) Auckland, Wellington", value: "Pacific/Auckland", offset: "-720"],
    [key: "(GMT+12:00) Fiji, Kamchatka, Marshall Is.", value: "Pacific/Fiji"],
    [key: "(GMT+13:00) Nuku'alofa", value: "Pacific/Tongatapu", offset: "-780"]
  ]

  def options() do
    @options
  end
end
