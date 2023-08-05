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

  @spec allow(Plausible.Site.t(), [prop()] | prop()) ::
          {:ok, Plausible.Site.t()} | {:error, Ecto.Changeset.t()}
  @doc """
  Allows a prop key or a list of props keys to be included in ClickHouse
  queries. Allowing prop keys does not affect ingestion, as we don't want any
  data to be dropped or lost.
  """
  def allow(site, prop_or_props) do
    site
    |> allow_changeset(prop_or_props)
    |> Plausible.Repo.update()
  end

  def allow_changeset(site, prop_or_props) do
    old_props = site.allowed_event_props || []
    new_props = List.wrap(prop_or_props) ++ old_props

    changeset(site, new_props)
  end

  @spec disallow(Plausible.Site.t(), prop()) ::
          {:ok, Plausible.Site.t()} | {:error, Ecto.Changeset.t()}
  @doc """
  Removes a previously allowed prop key from the allow list. This means this
  prop key won't be included in ClickHouse queries. This doesn't drop any
  ClickHouse data, nor affects ingestion.
  """
  def disallow(site, prop) do
    allowed_event_props = site.allowed_event_props || []

    site
    |> changeset(allowed_event_props -- [prop])
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

  @spec allow_existing_props(Plausible.Site.t()) :: {:ok, Plausible.Site.t()}
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

  @internal_keys ~w(url path)
  @doc """
  Lists prop keys used internally.

  These props should be allowed by default, and should not be displayed in the
  props settings page. For example, `url` is a special prop key used for file
  downloads and outbound links. It doesn't make sense to remove this prop key
  from the allow list, or to suggest users to add this prop key.
  """
  def internal_keys, do: @internal_keys

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

  def enabled_for?(%Plausible.Auth.User{} = user) do
    FunWithFlags.enabled?(:props, for: user)
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
