defmodule PlausibleWeb.Api.Internal.AnnotationsController do
  @moduledoc """
  Internal API controller for segments.
  """
  use Plausible
  use PlausibleWeb, :controller
  use PlausibleWeb.Plugs.ErrorHandler
  alias PlausibleWeb.Api.Helpers, as: H
  alias Plausible.Annotations

  def index(
        %Plug.Conn{
          assigns:
            %{
              site: site,
              site_role: site_role
            } = assigns
        } = conn,
        %{} = _params
      ) do
    user_id =
      case assigns[:current_user] do
        %{id: id} -> id
        nil -> nil
      end

    case Annotations.get_all_for_site(site, site_role, user_id) do
      {:ok, result} -> json(conn, result)
      {:error, :not_enough_permissions} -> json(conn, "Not enough permissions to get annotations")
    end
  end

  def create(
        %Plug.Conn{
          assigns: %{
            site: site,
            current_user: %{id: user_id},
            site_role: site_role
          }
        } = conn,
        %{} = params
      ) do
    case Annotations.insert_one(user_id, site, site_role, params) do
      {:error, :not_enough_permissions} ->
        H.not_enough_permissions(conn, "Not enough permissions to create annotation")

      {:error, :annotations_limit_reached} ->
        H.not_enough_permissions(conn, "Annotations limit reached")

      {:error, {:invalid_annotation, errors}} when is_list(errors) ->
        conn
        |> put_status(400)
        |> json(%{
          error: Annotations.serialize_first_error(errors)
        })

      {:ok, segment} ->
        json(conn, segment)
    end
  end

  def create(%Plug.Conn{} = conn, _params), do: invalid_request(conn)

  def update(
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
    annotation_id = normalize_annotation_id_param(params["annotation_id"])

    case Annotations.update_one(user_id, site, site_role, annotation_id, params) do
      {:error, :not_enough_permissions} ->
        H.not_enough_permissions(conn, "Not enough permissions to edit segment")

      {:error, :annotation_not_found} ->
        annotation_not_found(conn, params["annotation_id"])

      {:error, {:invalid_annotation, errors}} when is_list(errors) ->
        conn
        |> put_status(400)
        |> json(%{
          error: Annotations.serialize_first_error(errors)
        })

      {:ok, segment} ->
        json(conn, segment)
    end
  end

  def update(%Plug.Conn{} = conn, _params), do: invalid_request(conn)

  def delete(
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
    annotation_id = normalize_annotation_id_param(params["annotation_id"])

    case Annotations.delete_one(user_id, site, site_role, annotation_id) do
      {:error, :not_enough_permissions} ->
        H.not_enough_permissions(conn, "Not enough permissions to delete segment")

      {:error, :annotation_not_found} ->
        annotation_not_found(conn, params["annotation_id"])

      {:ok, segment} ->
        json(conn, segment)
    end
  end

  def delete(%Plug.Conn{} = conn, _params), do: invalid_request(conn)

  @spec normalize_annotation_id_param(any()) :: nil | pos_integer()
  defp normalize_annotation_id_param(input) do
    case Integer.parse(input) do
      {int_value, ""} when int_value > 0 -> int_value
      _ -> nil
    end
  end

  defp annotation_not_found(%Plug.Conn{} = conn, annotation_id_param) do
    H.not_found(conn, "Annotation not found with ID #{inspect(annotation_id_param)}")
  end

  defp invalid_request(%Plug.Conn{} = conn) do
    H.bad_request(conn, "Invalid request")
  end
end
