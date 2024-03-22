defmodule Plausible.Google.GA4.ReportRequest do
  @moduledoc """
  Report request struct for Google Analytics 4 API
  """

  defstruct [
    :dataset,
    :dimensions,
    :metrics,
    :date_range,
    :property,
    :access_token,
    :offset,
    :limit
  ]

  @type t() :: %__MODULE__{
          dataset: String.t(),
          dimensions: [String.t()],
          metrics: [String.t()],
          date_range: Date.Range.t(),
          property: term(),
          access_token: String.t(),
          offset: non_neg_integer(),
          limit: non_neg_integer()
        }

  def full_report do
    [
      %__MODULE__{
        dataset: "imported_visitors",
        dimensions: ["date"],
        metrics: [
          "totalUsers",
          "screenPageViews",
          "bounces = sessions - engagedSessions",
          "sessions",
          "userEngagementDuration"
        ]
      },
      %__MODULE__{
        dataset: "imported_sources",
        dimensions: [
          "date",
          "sessionSource",
          "sessionMedium",
          "sessionCampaignName",
          "sessionManualAdContent",
          "sessionGoogleAdsKeyword"
        ],
        metrics: [
          "totalUsers",
          "sessions",
          "bounces = sessions - engagedSessions",
          "userEngagementDuration"
        ]
      },
      %__MODULE__{
        dataset: "imported_pages",
        dimensions: ["date", "hostName", "pagePath"],
        # NOTE: no exits as GA4 DATA API does not provide that metric
        metrics: ["totalUsers", "screenPageViews", "userEngagementDuration"]
      },
      %__MODULE__{
        dataset: "imported_entry_pages",
        dimensions: ["date", "landingPage"],
        metrics: [
          "totalUsers",
          "sessions",
          "userEngagementDuration",
          "bounces = sessions - engagedSessions"
        ]
      },
      # NOTE: Skipping for now as there's no dimension directly mapping to exit page path
      # %__MODULE__{
      #   dataset: "imported_exit_pages",
      #   dimensions: ["date", "ga:exitPagePath"],
      #   metrics: ["totalUsers", "sessions"]
      # },
      %__MODULE__{
        dataset: "imported_locations",
        dimensions: ["date", "countryId", "region", "city"],
        metrics: [
          "totalUsers",
          "sessions",
          "bounces = sessions - engagedSessions",
          "userEngagementDuration"
        ]
      },
      %__MODULE__{
        dataset: "imported_devices",
        dimensions: ["date", "deviceCategory"],
        metrics: [
          "totalUsers",
          "sessions",
          "bounces = sessions - engagedSessions",
          "userEngagementDuration"
        ]
      },
      %__MODULE__{
        dataset: "imported_browsers",
        dimensions: ["date", "browser"],
        metrics: [
          "totalUsers",
          "sessions",
          "bounces = sessions - engagedSessions",
          "userEngagementDuration"
        ]
      },
      %__MODULE__{
        dataset: "imported_operating_systems",
        dimensions: ["date", "operatingSystem"],
        metrics: [
          "totalUsers",
          "sessions",
          "bounces = sessions - engagedSessions",
          "userEngagementDuration"
        ]
      }
    ]
  end
end
