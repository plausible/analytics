defmodule Plausible.Billing.Feature do
  @moduledoc """
  This module provides an interface for managing features, e.g. Revenue Goals,
  Funnels and Custom Properties.

  Feature modules have functions for toggling the feature on/off and checking
  whether the feature is available for a site/user.

  When defining new features, the following options are expected by the
  `__using__` macro:

    * `:name` - an atom representing the feature name in the plan JSON
    file (see also Plausible.Billing.Plan).

    * `:display_name` - human-readable display name of the feature

    * `:toggle_field` - the field in the %Plausible.Site{} schema that toggles
    the feature. If `nil` or not set, toggle/2 silently returns `:ok`

    * `:free` - if set to `true`, makes the `check_availability/1` function
    always return `:ok` (no matter the user's subscription status)

  Functions defined by `__using__` can be overridden if needed.
  """

  @doc """
  Returns the atom representing the feature name in the plan JSON file.
  """
  @callback name() :: atom()

  @doc """
  Returns the human-readable display name of the feature.
  """
  @callback display_name() :: String.t()

  @doc """
  Returns the %Plausible.Site{} field that toggles the feature on and off.
  """
  @callback toggle_field() :: atom()

  @doc """
  Toggles the feature on and off for a site. Returns
  `{:error, :upgrade_required}` when toggling a feature the site owner does not
  have access to.
  """
  @callback toggle(Plausible.Site.t(), Keyword.t()) :: :ok | {:error, :upgrade_required}

  @doc """
  Checks whether a feature is enabled or not. Returns false when the feature is
  disabled or the user does not have access to it.
  """
  @callback enabled?(Plausible.Site.t()) :: boolean()

  @doc """
  Checks whether the site owner or the user plan includes the given feature.
  """
  @callback check_availability(Plausible.Auth.User.t()) ::
              :ok | {:error, :upgrade_required} | {:error, :not_implemented}

  @features [
    Plausible.Billing.Feature.Goals,
    Plausible.Billing.Feature.StatsAPI,
    Plausible.Billing.Feature.Props,
    Plausible.Billing.Feature.Funnels,
    Plausible.Billing.Feature.RevenueGoals
  ]

  @doc """
  Lists all available feature modules.
  """
  def list() do
    @features
  end

  @doc false
  defmacro __using__(opts \\ []) do
    quote location: :keep do
      @behaviour Plausible.Billing.Feature
      alias Plausible.Billing.Quota

      @impl true
      def name, do: Keyword.get(unquote(opts), :name)

      @impl true
      def display_name, do: Keyword.get(unquote(opts), :display_name)

      @impl true
      def toggle_field, do: Keyword.get(unquote(opts), :toggle_field)

      @impl true
      def enabled?(%Plausible.Site{} = site) do
        site = Plausible.Repo.preload(site, :owner)

        cond do
          check_availability(site.owner) !== :ok -> false
          is_nil(toggle_field()) -> true
          true -> Map.fetch!(site, toggle_field())
        end
      end

      @impl true
      def check_availability(%Plausible.Auth.User{} = user) do
        cond do
          not FunWithFlags.enabled?(:business_tier, for: user) -> :ok
          Keyword.get(unquote(opts), :free) -> :ok
          __MODULE__ in Quota.allowed_features_for(user) -> :ok
          true -> {:error, :upgrade_required}
        end
      end

      @impl true
      def toggle(%Plausible.Site{} = site, opts \\ []) do
        with key when not is_nil(key) <- toggle_field(),
             site <- Plausible.Repo.preload(site, :owner),
             :ok <- check_availability(site.owner) do
          override = Keyword.get(opts, :override)
          toggle = if is_boolean(override), do: override, else: !Map.fetch!(site, toggle_field())

          site
          |> Ecto.Changeset.change(%{toggle_field() => toggle})
          |> Plausible.Repo.update()
        else
          nil = _feature_not_togglable -> :ok
          {:error, :upgrade_required} -> {:error, :upgrade_required}
        end
      end
    end
  end
end

defmodule Plausible.Billing.Feature.Funnels do
  @moduledoc false
  use Plausible.Billing.Feature,
    name: :funnels,
    display_name: "Funnels",
    toggle_field: :funnels_enabled
end

defmodule Plausible.Billing.Feature.RevenueGoals do
  @moduledoc false
  use Plausible.Billing.Feature,
    name: :revenue_goals,
    display_name: "Revenue Goals"
end

defmodule Plausible.Billing.Feature.Goals do
  @moduledoc false
  use Plausible.Billing.Feature,
    name: :goals,
    display_name: "Goals",
    toggle_field: :conversions_enabled,
    free: true
end

defmodule Plausible.Billing.Feature.Props do
  @moduledoc false
  use Plausible.Billing.Feature,
    name: :props,
    display_name: "Custom Properties",
    toggle_field: :props_enabled
end

defmodule Plausible.Billing.Feature.StatsAPI do
  @moduledoc false
  use Plausible.Billing.Feature,
    name: :stats_api,
    display_name: "Stats API"
end
