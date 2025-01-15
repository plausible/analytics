defmodule Plausible.Segments do
  @moduledoc """
  Module for accessing Segments.
  """
  alias __MODULE__
  use Plausible.Repo

  @type error_not_enough_permissions() :: {:error, :not_enough_permissions}
  @type error_segment_not_found() :: {:error, :segment_not_found}

  @spec index(pos_integer() | nil, Plausible.Site.t(), atom()) ::
          {:ok, [Segments.Segment.t()]} | error_not_enough_permissions()
  def index(user_id, %Plausible.Site{} = site, site_role) do
    fields_in_index_query = [
      :id,
      :name,
      :type,
      :inserted_at,
      :updated_at,
      :owner_id
    ]

    site_segments_available? =
      site_segments_available?(site)

    cond do
      site_role in [:public] and
          site_segments_available? ->
        {:ok,
         Repo.all(get_site_segments_only_query(site.id, fields_in_index_query -- [:owner_id]))}

      site_role in Segments.roles_with_maybe_site_segments() and
          site_segments_available? ->
        {:ok,
         Repo.all(get_personal_and_site_segments_query(user_id, site.id, fields_in_index_query))}

      site_role in Segments.roles_with_personal_segments() ->
        {:ok, Repo.all(get_personal_segments_only_query(user_id, site.id, fields_in_index_query))}

      true ->
        {:error, :not_enough_permissions}
    end
  end

  @spec get_one(pos_integer(), Plausible.Site.t(), atom(), pos_integer() | nil) ::
          {:ok, Segments.Segment.t()}
          | error_not_enough_permissions()
          | error_segment_not_found()
  def get_one(user_id, site, site_role, segment_id) do
    if site_role in roles_with_personal_segments() do
      case do_get_one(user_id, site.id, segment_id) do
        %Segments.Segment{} = segment -> {:ok, segment}
        nil -> {:error, :segment_not_found}
      end
    else
      {:error, :not_enough_permissions}
    end
  end

  def insert_one(
        user_id,
        %Plausible.Site{} = site,
        site_role,
        %{} = params
      ) do
    with :ok <- can_insert_one?(site, site_role, params),
         %{valid?: true} = changeset <-
           Plausible.Segments.Segment.changeset(
             %Plausible.Segments.Segment{},
             Map.merge(params, %{"site_id" => site.id, "owner_id" => user_id})
           ),
         :ok <-
           Plausible.Segments.Segment.validate_segment_data(site, params["segment_data"], true) do
      {:ok, Repo.insert!(changeset)}
    else
      %{valid?: false, errors: errors} ->
        {:error, {:invalid_segment, errors}}

      {:error, {:invalid_filters, message}} ->
        {:error, {:invalid_segment, segment_data: {message, []}}}

      {:error, _type} = error ->
        error
    end
  end

  def update_one(
        user_id,
        %Plausible.Site{} = site,
        site_role,
        segment_id,
        %{} = params
      ) do
    with {:ok, segment} <- get_one(user_id, site, site_role, segment_id),
         :ok <- can_update_one?(site, site_role, params, segment.type),
         %{valid?: true} = changeset <-
           Segments.Segment.changeset(
             segment,
             Map.merge(params, %{"owner_id" => user_id})
           ),
         :ok <-
           Segments.Segment.validate_segment_data_if_exists(
             site,
             params["segment_data"],
             true
           ) do
      {:ok,
       Repo.update!(
         changeset,
         returning: true
       )}
    else
      %{valid?: false, errors: errors} ->
        {:error, {:invalid_segment, errors}}

      {:error, {:invalid_filters, message}} ->
        {:error, {:invalid_segment, segment_data: {message, []}}}

      {:error, _type} = error ->
        error
    end
  end

  def delete_one(user_id, %Plausible.Site{} = site, site_role, segment_id) do
    with {:ok, segment} <- get_one(user_id, site, site_role, segment_id) do
      cond do
        segment.type == :site and site_role in roles_with_maybe_site_segments() ->
          {:ok, do_delete_one(segment)}

        segment.type == :personal and site_role in roles_with_personal_segments() ->
          {:ok, do_delete_one(segment)}

        true ->
          {:error, :not_enough_permissions}
      end
    end
  end

  @spec do_get_one(pos_integer(), pos_integer(), pos_integer() | nil) ::
          Segments.Segment.t() | nil
  defp do_get_one(user_id, site_id, segment_id)

  defp do_get_one(_user_id, _site_id, nil) do
    nil
  end

  defp do_get_one(user_id, site_id, segment_id) do
    query =
      from(segment in Plausible.Segments.Segment,
        where: segment.site_id == ^site_id,
        where: segment.id == ^segment_id,
        where: segment.type == :site or segment.owner_id == ^user_id
      )

    Repo.one(query)
  end

  defp do_delete_one(segment) do
    Repo.delete!(segment)
    segment
  end

  defp can_update_one?(%Plausible.Site{} = site, site_role, params, existing_segment_type) do
    updating_to_site_segment? = params["type"] == "site"

    cond do
      (existing_segment_type == :site or
         updating_to_site_segment?) and site_role in roles_with_maybe_site_segments() and
          site_segments_available?(site) ->
        :ok

      existing_segment_type == :personal and not updating_to_site_segment? and
          site_role in roles_with_personal_segments() ->
        :ok

      true ->
        {:error, :not_enough_permissions}
    end
  end

  defp can_insert_one?(%Plausible.Site{} = site, site_role, params) do
    cond do
      params["type"] == "site" and site_role in roles_with_maybe_site_segments() and
          site_segments_available?(site) ->
        :ok

      params["type"] == "personal" and
          site_role in roles_with_personal_segments() ->
        :ok

      true ->
        {:error, :not_enough_permissions}
    end
  end

  def roles_with_personal_segments(), do: [:viewer, :editor, :admin, :owner, :super_admin]
  def roles_with_maybe_site_segments(), do: [:editor, :admin, :owner, :super_admin]

  def site_segments_available?(%Plausible.Site{} = site),
    do: Plausible.Billing.Feature.Props.check_availability(site.team) == :ok

  @spec get_site_segments_only_query(pos_integer(), list(atom())) :: Ecto.Query.t()
  defp get_site_segments_only_query(site_id, fields) do
    from(segment in Plausible.Segments.Segment,
      select: ^fields,
      where: segment.site_id == ^site_id,
      where: segment.type == :site,
      order_by: [desc: segment.updated_at, desc: segment.id]
    )
  end

  @spec get_personal_segments_only_query(pos_integer(), pos_integer(), list(atom())) ::
          Ecto.Query.t()
  defp get_personal_segments_only_query(user_id, site_id, fields) do
    from(segment in Plausible.Segments.Segment,
      select: ^fields,
      where: segment.site_id == ^site_id,
      where: segment.type == :personal and segment.owner_id == ^user_id,
      order_by: [desc: segment.updated_at, desc: segment.id]
    )
  end

  @spec get_personal_and_site_segments_query(pos_integer(), pos_integer(), list(atom())) ::
          Ecto.Query.t()
  defp get_personal_and_site_segments_query(user_id, site_id, fields) do
    from(segment in Plausible.Segments.Segment,
      select: ^fields,
      where: segment.site_id == ^site_id,
      where:
        segment.type == :site or (segment.type == :personal and segment.owner_id == ^user_id),
      order_by: [desc: segment.updated_at, desc: segment.id]
    )
  end
end
