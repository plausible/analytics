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
  Returns whether the feature is free to use or not.
  """
  @callback free?() :: boolean()

  @doc """
  Toggles the feature on and off for a site. Returns
  `{:error, :upgrade_required}` when toggling a feature the site owner does not
  have access to.
  """
  @callback toggle(Plausible.Site.t(), Plausible.Auth.User.t(), Keyword.t()) ::
              :ok | {:error, :upgrade_required}

  @doc """
  Checks whether a feature is enabled or not. Returns false when the feature is
  disabled or the user does not have access to it.
  """
  @callback enabled?(Plausible.Site.t()) :: boolean()

  @doc """
  Returns whether the site explicitly opted out of the feature. This function
  is different from enabled/1, because enabled/1 returns false when the site
  owner does not have access to the feature.
  """
  @callback opted_out?(Plausible.Site.t()) :: boolean()

  @doc """
  Checks whether the team or the team plan includes the given feature.
  """
  @callback check_availability(Plausible.Teams.Team.t() | nil) ::
              :ok | {:error, :upgrade_required} | {:error, :not_implemented}

  @features [
    Plausible.Billing.Feature.Goals,
    Plausible.Billing.Feature.StatsAPI,
    Plausible.Billing.Feature.Props,
    Plausible.Billing.Feature.Funnels,
    Plausible.Billing.Feature.RevenueGoals
  ]

  # Generate a union type for features
  @type t() :: unquote(Enum.reduce(@features, &{:|, [], [&1, &2]}))

  @doc """
  Lists all available feature modules.
  """
  def list() do
    @features
  end

  @doc """
  Lists all the feature short names, e.g. RevenueGoals
  """
  defmacro list_short_names() do
    @features
    |> Enum.map(fn mod ->
      Module.split(mod)
      |> List.last()
      |> String.to_atom()
    end)
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
      def free?, do: Keyword.get(unquote(opts), :free, false)

      @impl true
      def enabled?(%Plausible.Site{} = site) do
        site = Plausible.Repo.preload(site, :team)
        check_availability(site.team) == :ok && !opted_out?(site)
      end

      @impl true
      def opted_out?(%Plausible.Site{} = site) do
        if is_nil(toggle_field()), do: false, else: !Map.fetch!(site, toggle_field())
      end

      @impl true
      def check_availability(team_or_nil) do
        cond do
          free?() -> :ok
          __MODULE__ in Plausible.Teams.Billing.allowed_features_for(team_or_nil) -> :ok
          true -> {:error, :upgrade_required}
        end
      end

      @impl true
      def toggle(%Plausible.Site{} = site, %Plausible.Auth.User{} = user, opts \\ []) do
        if toggle_field(), do: do_toggle(site, user, opts), else: :ok
      end

      defp do_toggle(%Plausible.Site{} = site, user, opts) do
        override = Keyword.get(opts, :override)
        toggle = if is_boolean(override), do: override, else: !Map.fetch!(site, toggle_field())
        availability = if toggle, do: check_availability(site.team), else: :ok

        case availability do
          :ok ->
            site
            |> Ecto.Changeset.change(%{toggle_field() => toggle})
            |> Plausible.Repo.update()

          error ->
            error
        end
      end

      defoverridable check_availability: 1
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
  use Plausible

  @moduledoc false
  use Plausible.Billing.Feature,
    name: :stats_api,
    display_name: "Stats API"
end
