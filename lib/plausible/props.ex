defmodule Plausible.Props do
  @moduledoc """
  Context module for handling custom event props.
  """

  import Ecto.Query

  @type prop :: String.t()

  @max_props 300
  def max_props, do: @max_props

  @max_prop_key_length 300
  def max_prop_key_length, do: @max_prop_key_length

  @max_prop_value_length 2000
  def max_prop_value_length, do: @max_prop_value_length

  # NOTE: Keep up to date with `Plausible.Imported.imported_custom_props/0`.
  @internal_keys ~w(url path search_query form)

  @doc """
  Lists prop keys used internally.

  These props should be allowed by default, and should not be displayed in the
  props settings page. For example, `url` is a special prop key used for file
  downloads and outbound links. It doesn't make sense to remove this prop key
  from the allow list, or to suggest users to add this prop key.
  """
  def internal_keys, do: @internal_keys

  @doc """
  Returns the custom props allowed in queries for the given site. There are
  two factors deciding whether a custom property is allowed for a site.

  ### 1. Subscription plan including the props feature.

  Internally used keys (i.e. `#{inspect(@internal_keys)}`) are always allowed,
  even for plans that don't include props. For any other props, access to the
  Custom Properties feature is required.

  ### 2. The site having an `allowed_event_props` list configured.

  For customers with a configured `allowed_event_props` list, this function
  returns that list (+ internally used keys). That helps to filter out garbage
  props which people might not want to see in their dashboards.

  With the `bypass_setup?` boolean option you can override the requirement of
  the site having set up props in the `allowed_event_props` list. For example,
  this is currently used for fetching allowed properties in Stats API queries
  in order to ensure the props feature access.

  Since `allowed_event_props` was added after the props feature had already
  been used for a while, there are sites with `allowed_event_props = nil`. For
  those sites, all custom properties that exist in the database are allowed to
  be queried.
  """
  @spec allowed_for(Plausible.Site.t()) :: [prop()] | :all
  def allowed_for(site, opts \\ []) do
    site = Plausible.Repo.preload(site, :team)
    internal_keys = Plausible.Props.internal_keys()
    props_enabled? = Plausible.Billing.Feature.Props.check_availability(site.team) == :ok
    bypass_setup? = Keyword.get(opts, :bypass_setup?)

    cond do
      props_enabled? && is_nil(site.allowed_event_props) -> :all
      props_enabled? && bypass_setup? -> :all
      props_enabled? -> site.allowed_event_props ++ internal_keys
      true -> internal_keys
    end
  end

  @spec allow(Plausible.Site.t(), [prop()] | prop()) ::
          {:ok, Plausible.Site.t()} | {:error, Ecto.Changeset.t()} | {:error, :upgrade_required}
  @doc """
  Allows a prop key or a list of props keys to be included in ClickHouse
  queries. Allowing prop keys does not affect ingestion, as we don't want any
  data to be dropped or lost.
  """
  def allow(site, prop_or_props) do
    with site <- Plausible.Repo.preload(site, :team),
         :ok <- Plausible.Billing.Feature.Props.check_availability(site.team) do
      site
      |> allow_changeset(prop_or_props)
      |> Plausible.Repo.update()
    end
  end

  def allow_changeset(site, prop_or_props) do
    old_props = site.allowed_event_props || []
    new_props = List.wrap(prop_or_props) ++ old_props

    changeset(site, new_props)
  end

  @spec disallow(Plausible.Site.t(), [prop()] | prop()) ::
          {:ok, Plausible.Site.t()} | {:error, Ecto.Changeset.t()}
  @doc """
  Removes previously allowed prop key(s) from the allow list. This means this
  prop key won't be included in ClickHouse queries. This doesn't drop any
  ClickHouse data, nor affects ingestion.
  """
  def disallow(site, prop_or_props) do
    allowed_event_props = site.allowed_event_props || []

    site
    |> changeset(allowed_event_props -- List.wrap(prop_or_props))
    |> Plausible.Repo.update()
  end

  defp changeset(site, props) do
    props =
      props
      |> Enum.map(&String.trim/1)
      |> Enum.uniq()

    site
    |> Ecto.Changeset.change(allowed_event_props: props)
    |> Ecto.Changeset.validate_length(:allowed_event_props, max: @max_props)
    |> Ecto.Changeset.validate_change(:allowed_event_props, fn field, allowed_props ->
      if Enum.all?(allowed_props, &valid?/1),
        do: [],
        else: [{field, "must be between 1 and #{@max_prop_key_length} characters"}]
    end)
  end

  @spec allow_existing_props(Plausible.Site.t()) ::
          {:ok, Plausible.Site.t()} | {:error, :upgrade_required}
  @doc """
  Allows the #{@max_props} most frequent props keys for a specific site over
  the past 6 months.
  """
  def allow_existing_props(%Plausible.Site{} = site) do
    props_to_allow =
      site
      |> suggest_keys_to_allow()
      |> Enum.filter(&valid?/1)

    allow(site, props_to_allow)
  end

  def ensure_prop_key_accessible(prop_key, team) do
    if prop_key in @internal_keys do
      :ok
    else
      Plausible.Billing.Feature.Props.check_availability(team)
    end
  end

  @spec suggest_keys_to_allow(Plausible.Site.t(), non_neg_integer()) :: [String.t()]
  @doc """
  Queries the events table to fetch the #{@max_props} most frequent prop keys
  for a specific site over the past 6 months, excluding keys that are already
  allowed.
  """
  def suggest_keys_to_allow(%Plausible.Site{} = site, limit \\ @max_props) do
    allowed_event_props = site.allowed_event_props || []

    unnested_keys =
      from e in Plausible.ClickhouseEventV2,
        where: e.site_id == ^site.id,
        where: fragment("? > (NOW() - INTERVAL 6 MONTH)", e.timestamp),
        select: %{key: fragment("arrayJoin(?)", field(e, :"meta.key"))}

    Plausible.ClickhouseRepo.all(
      from uk in subquery(unnested_keys),
        where: uk.key not in ^allowed_event_props,
        where: uk.key not in ^@internal_keys,
        group_by: uk.key,
        select: uk.key,
        order_by: {:desc, count(uk.key)},
        limit: ^limit
    )
  end

  defp valid?(key) do
    String.length(key) in 1..@max_prop_key_length
  end

  @doc """
  Returns whether the site has configured custom props or not.
  """
  def configured?(%Plausible.Site{allowed_event_props: allowed_event_props}) do
    is_list(allowed_event_props) && length(allowed_event_props) > 0
  end
end
