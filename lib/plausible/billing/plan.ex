defmodule Plausible.Billing.Plan do
  @moduledoc false

  @derive Jason.Encoder
  @enforce_keys ~w(kind site_limit monthly_pageview_limit team_member_limit features volume monthly_product_id yearly_product_id)a
  defstruct @enforce_keys ++ [:monthly_cost, :yearly_cost]

  @type t() ::
          %__MODULE__{
            kind: atom(),
            monthly_pageview_limit: non_neg_integer(),
            site_limit: non_neg_integer(),
            team_member_limit: non_neg_integer() | :unlimited,
            volume: String.t(),
            monthly_cost: Money.t() | nil,
            yearly_cost: Money.t() | nil,
            monthly_product_id: String.t() | nil,
            yearly_product_id: String.t() | nil,
            features: [atom()]
          }
          | :enterprise

  def new(params, file_name) when is_map(params) do
    params =
      params
      |> put_kind()
      |> put_volume()
      |> put_team_member_limit(file_name)
      |> put_features(file_name)

    struct!(__MODULE__, params)
  end

  defp put_kind(params) do
    Map.put(params, :kind, String.to_atom(params.kind))
  end

  defp put_volume(params) do
    volume =
      params.monthly_pageview_limit
      |> PlausibleWeb.StatsView.large_number_format()

    Map.put(params, :volume, volume)
  end

  defp put_team_member_limit(params, file_name) do
    team_member_limit =
      case params.team_member_limit do
        number when is_integer(number) ->
          number

        "unlimited" ->
          :unlimited

        other ->
          raise ArgumentError,
                "Failed to parse team member limit #{inspect(other)} from #{file_name}.json"
      end

    Map.put(params, :team_member_limit, team_member_limit)
  end

  defp put_features(params, file_name) do
    features =
      Plausible.Billing.Feature.list()
      |> Enum.filter(fn module ->
        to_string(module.name()) in params.features
      end)

    if length(features) == length(params.features) do
      Map.put(params, :features, features)
    else
      raise(
        ArgumentError,
        "Unrecognized feature(s) in #{inspect(params.features)} (#{file_name}.json)"
      )
    end
  end
end
