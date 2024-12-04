defmodule Plausible.Teams.Adapter.Read.Ownership do
  @moduledoc """
  Transition adapter for new schema reads
  """
  use Plausible
  use Plausible.Teams.Adapter

  on_ee do
    def check_feature_access(site, new_owner) do
      missing_features =
        Plausible.Billing.Quota.Usage.features_usage(nil, [site.id])
        |> Enum.filter(&(&1.check_availability(new_owner) != :ok))

      if missing_features == [] do
        :ok
      else
        {:error, {:missing_features, missing_features}}
      end
    end
  else
    def check_feature_access(_site, _new_owner) do
      :ok
    end
  end
end
