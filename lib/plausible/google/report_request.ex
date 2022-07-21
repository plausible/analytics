defmodule Plausible.Google.ReportRequest do
  defstruct [
    :dataset,
    :dimensions,
    :metrics,
    :date_range,
    :view_id,
    :access_token,
    :page_token,
    :page_size
  ]

  @type t() :: %__MODULE__{
          dataset: String.t(),
          dimensions: [String.t()],
          metrics: [String.t()],
          date_range: Date.Range.t(),
          view_id: term(),
          access_token: String.t(),
          page_token: String.t() | nil,
          page_size: non_neg_integer()
        }

  def full_report do
    [
      %__MODULE__{
        dataset: "imported_visitors",
        dimensions: ["ga:date"],
        metrics: ["ga:users", "ga:pageviews", "ga:bounces", "ga:sessions", "ga:sessionDuration"]
      },
      %__MODULE__{
        dataset: "imported_sources",
        dimensions: [
          "ga:date",
          "ga:source",
          "ga:medium",
          "ga:campaign",
          "ga:adContent",
          "ga:keyword"
        ],
        metrics: ["ga:users", "ga:sessions", "ga:bounces", "ga:sessionDuration"]
      },
      %__MODULE__{
        dataset: "imported_pages",
        dimensions: ["ga:date", "ga:hostname", "ga:pagePath"],
        metrics: ["ga:users", "ga:pageviews", "ga:exits", "ga:timeOnPage"]
      },
      %__MODULE__{
        dataset: "imported_entry_pages",
        dimensions: ["ga:date", "ga:landingPagePath"],
        metrics: ["ga:users", "ga:entrances", "ga:sessionDuration", "ga:bounces"]
      },
      %__MODULE__{
        dataset: "imported_exit_pages",
        dimensions: ["ga:date", "ga:exitPagePath"],
        metrics: ["ga:users", "ga:exits"]
      },
      %__MODULE__{
        dataset: "imported_locations",
        dimensions: ["ga:date", "ga:countryIsoCode", "ga:regionIsoCode"],
        metrics: ["ga:users", "ga:sessions", "ga:bounces", "ga:sessionDuration"]
      },
      %__MODULE__{
        dataset: "imported_devices",
        dimensions: ["ga:date", "ga:deviceCategory"],
        metrics: ["ga:users", "ga:sessions", "ga:bounces", "ga:sessionDuration"]
      },
      %__MODULE__{
        dataset: "imported_browsers",
        dimensions: ["ga:date", "ga:browser"],
        metrics: ["ga:users", "ga:sessions", "ga:bounces", "ga:sessionDuration"]
      },
      %__MODULE__{
        dataset: "imported_operating_systems",
        dimensions: ["ga:date", "ga:operatingSystem"],
        metrics: ["ga:users", "ga:sessions", "ga:bounces", "ga:sessionDuration"]
      }
    ]
  end
end
