defmodule PlausibleWeb.Api.Internal.SegmentsController do
  use Plausible
  use PlausibleWeb, :controller
  use Plausible.Repo
  use PlausibleWeb.Plugs.ErrorHandler
  alias PlausibleWeb.Api.Helpers, as: H

  @fields_in_index_query [
    :id,
    :name,
    :type,
    :inserted_at,
    :updated_at,
    :owner_id
  ]

  def get_all_segments(
        %Plug.Conn{
          assigns: %{
            site: site,
            site_role: site_role,
            current_user: current_user
          }
        } = conn,
        %{} = _params
      ) do
    site_segments_available? =
      site_segments_available?(site)

    cond do
      site_role in roles_with_personal_segments() and
          site_segments_available? ->
        result =
          Repo.all(
            get_personal_and_site_segments_query(current_user.id, site.id, @fields_in_index_query)
          )

        json(conn, result)

      site_role in roles_with_personal_segments() ->
        result =
          Repo.all(
            get_personal_segments_only_query(current_user.id, site.id, @fields_in_index_query)
          )

        json(conn, result)

      site_role in [:public] and site_segments_available? ->
        result =
          Repo.all(
            get_site_segments_only_query(
              site.id,
              @fields_in_index_query -- [:owner_id]
            )
          )

        json(conn, result)

      true ->
        H.not_enough_permissions(conn, "Not enough permissions to get segments")
    end
  end

  def get_segment(
        %Plug.Conn{
          assigns: %{
            site: site,
            current_user: current_user,
            site_role: site_role
          }
        } = conn,
        %{} = params
      ) do
    segment_id = normalize_segment_id_param(params["segment_id"])

    if site_role in roles_with_personal_segments() do
      result = get_one_segment(current_user.id, site.id, segment_id)

      case result do
        nil -> H.not_found(conn, "Segment not found with ID #{inspect(params["segment_id"])}")
        result when is_map(result) -> json(conn, result)
      end
    else
      H.not_enough_permissions(conn, "Not enough permissions to get segment data")
    end
  end

  def create_segment(
        %Plug.Conn{
          assigns: %{
            site: site,
            site_role: site_role
          }
        } = conn,
        %{} = params
      ) do
    site_segments_available? = site_segments_available?(site)

    cond do
      params["type"] == Atom.to_string(:personal) and
          site_role in roles_with_personal_segments() ->
        do_insert_segment(conn, params)

      params["type"] == Atom.to_string(:site) and site_segments_available? and
          site_role in roles_with_maybe_site_segments() ->
        do_insert_segment(conn, params)

      true ->
        H.not_enough_permissions(conn, "Not enough permissions to create segment")
    end
  end

  def create_segment(%Plug.Conn{} = conn, _params), do: H.bad_request(conn, "Invalid request")

  def update_segment(
        %Plug.Conn{
          assigns: %{
            site: site,
            current_user: %{id: user_id},
            site_role: site_role
          }
        } =
          conn,
        %{} = params
      ) do
    site_segments_available? = site_segments_available?(site)

    segment_id = normalize_segment_id_param(params["segment_id"])

    existing_segment = get_one_segment(user_id, site.id, segment_id)

    cond do
      is_nil(existing_segment) ->
        H.not_found(conn, "Segment not found with ID #{inspect(params["segment_id"])}")

      existing_segment.type == :personal and params["type"] != "site" and
          site_role in roles_with_personal_segments() ->
        do_update_segment(conn, params, existing_segment, user_id)

      existing_segment.type == :personal and params["type"] == "site" and site_segments_available? and
          site_role in roles_with_maybe_site_segments() ->
        do_update_segment(conn, params, existing_segment, user_id)

      existing_segment.type == :site and site_segments_available? and
          site_role in roles_with_maybe_site_segments() ->
        do_update_segment(conn, params, existing_segment, user_id)

      true ->
        H.not_enough_permissions(conn, "Not enough permissions to edit segment")
    end
  end

  def update_segment(%Plug.Conn{} = conn, _params), do: H.bad_request(conn, "Invalid request")

  def delete_segment(
        %Plug.Conn{
          assigns: %{
            site: site,
            current_user: %{id: user_id},
            site_role: site_role
          }
        } =
          conn,
        %{} = params
      ) do
    site_segments_available? = site_segments_available?(site)

    segment_id = normalize_segment_id_param(params["segment_id"])

    existing_segment = get_one_segment(user_id, site.id, segment_id)

    cond do
      is_nil(existing_segment) ->
        H.not_found(conn, "Segment not found with ID #{inspect(params["segment_id"])}")

      existing_segment.type == :personal and
          site_role in roles_with_personal_segments() ->
        do_delete_segment(conn, existing_segment)

      existing_segment.type == :site and
        site_segments_available? and
          site_role in roles_with_maybe_site_segments() ->
        do_delete_segment(conn, existing_segment)

      true ->
        H.not_enough_permissions(conn, "Not enough permissions to delete segment")
    end
  end

  def delete_segment(%Plug.Conn{} = conn, _params), do: H.bad_request(conn, "Invalid request")

  @spec get_site_segments_only_query(pos_integer(), list(atom())) :: Ecto.Query.t()
  defp get_site_segments_only_query(site_id, fields) do
    from(segment in Plausible.Segment,
      select: ^fields,
      where: segment.site_id == ^site_id,
      where: segment.type == :site,
      order_by: [desc: segment.updated_at, desc: segment.id]
    )
  end

  @spec get_personal_segments_only_query(pos_integer(), pos_integer(), list(atom())) ::
          Ecto.Query.t()
  defp get_personal_segments_only_query(user_id, site_id, fields) do
    from(segment in Plausible.Segment,
      select: ^fields,
      where: segment.site_id == ^site_id,
      where: segment.type == :personal and segment.owner_id == ^user_id,
      order_by: [desc: segment.updated_at, desc: segment.id]
    )
  end

  @spec get_personal_and_site_segments_query(pos_integer(), pos_integer(), list(atom())) ::
          Ecto.Query.t()
  defp get_personal_and_site_segments_query(user_id, site_id, fields) do
    from(segment in Plausible.Segment,
      select: ^fields,
      where: segment.site_id == ^site_id,
      where:
        segment.type == :site or (segment.type == :personal and segment.owner_id == ^user_id),
      order_by: [desc: segment.updated_at, desc: segment.id]
    )
  end

  @spec normalize_segment_id_param(any()) :: nil | pos_integer()
  defp normalize_segment_id_param(input) do
    case Integer.parse(input) do
      {int_value, ""} when int_value > 0 -> int_value
      _ -> nil
    end
  end

  defp get_one_segment(_user_id, _site_id, nil) do
    nil
  end

  defp get_one_segment(user_id, site_id, segment_id) do
    query =
      from(segment in Plausible.Segment,
        where: segment.site_id == ^site_id,
        where: segment.id == ^segment_id,
        where: segment.type == :site or segment.owner_id == ^user_id
      )

    Repo.one(query)
  end

  defp do_insert_segment(
         %Plug.Conn{
           assigns: %{
             site: site,
             current_user: %{id: user_id}
           }
         } = conn,
         %{} = params
       ) do
    segment_definition = Map.merge(params, %{"site_id" => site.id, "owner_id" => user_id})

    with %{valid?: true} = changeset <-
           Plausible.Segment.changeset(
             %Plausible.Segment{},
             segment_definition
           ),
         :ok <- Plausible.Segment.validate_segment_data(site, params["segment_data"], true) do
      segment = Repo.insert!(changeset)
      json(conn, segment)
    else
      %{valid?: false, errors: errors} ->
        conn
        |> put_status(400)
        |> json(%{
          errors: Enum.map(errors, fn {field_key, {message, _}} -> [field_key, message] end)
        })

      {:error, {:invalid_filters, message}} ->
        conn |> put_status(400) |> json(%{errors: [["segment_data", message]]})
    end
  end

  defp do_update_segment(
         %Plug.Conn{} = conn,
         %{} = params,
         %Plausible.Segment{} = existing_segment,
         owner_override
       ) do
    partial_segment_definition = Map.merge(params, %{"owner_id" => owner_override})

    with %{valid?: true} = changeset <-
           Plausible.Segment.changeset(
             existing_segment,
             partial_segment_definition
           ),
         :ok <-
           Plausible.Segment.validate_segment_data_if_exists(
             conn.assigns.site,
             params["segment_data"],
             true
           ) do
      json(
        conn,
        Repo.update!(
          changeset,
          returning: true
        )
      )
    else
      %{valid?: false, errors: errors} ->
        conn
        |> put_status(400)
        |> json(%{
          errors:
            Enum.map(errors, fn {field_key, {message, opts}} -> [field_key, message, opts] end)
        })

      {:error, {:invalid_filters, message}} ->
        conn |> put_status(400) |> json(%{errors: [["segment_data", message, []]]})
    end
  end

  defp do_delete_segment(
         %Plug.Conn{} = conn,
         %Plausible.Segment{} = existing_segment
       ) do
    Repo.delete!(existing_segment)
    json(conn, existing_segment)
  end

  defp roles_with_personal_segments(), do: [:viewer, :editor, :admin, :owner, :super_admin]
  defp roles_with_maybe_site_segments(), do: [:editor, :admin, :owner, :super_admin]

  defp site_segments_available?(site),
    do: Plausible.Billing.Feature.Props.check_availability(site.team) == :ok
end
