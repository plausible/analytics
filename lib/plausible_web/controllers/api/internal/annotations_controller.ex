defmodule PlausibleWeb.Api.Internal.AnnotationsController do
  @moduledoc """
  Internal API controller for annotations.
  """
  use Plausible
  use PlausibleWeb, :controller
  use PlausibleWeb.Plugs.ErrorHandler
  alias PlausibleWeb.Api.Helpers, as: H
  alias Plausible.Annotations
  alias Plausible.ChangesetHelpers
  alias Plausible.Stats.{ApiQueryParser, QueryPeriod}

  def index(conn, params) do
    user = conn.assigns.current_user
    site = conn.assigns.site
    site_role = conn.assigns.site_role

    with {:ok, input_date_range} <- parse_input_date_range(params),
         {:ok, relative_date} <- parse_relative_date(params) do
      now = DateTime.utc_now(:second)

      range_in_site_tz =
        QueryPeriod.build_range_for_site(input_date_range, site, relative_date, now)

      case Annotations.get_all_for_site(site, site_role, user, range_in_site_tz) do
        {:ok, result} ->
          json(conn, result)

        {:error, :not_enough_permissions} ->
          json(conn, "Not enough permissions to get annotations")
      end
    else
      {:error, message} -> H.bad_request(conn, message)
    end
  end

  defp parse_input_date_range(%{
         "date_range_start" => start,
         "date_range_end" => end_
       })
       when is_binary(start) and is_binary(end_) do
    case ApiQueryParser.parse_input_date_range([start, end_]) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, %{message: message}} -> {:error, message}
    end
  end

  defp parse_input_date_range(%{"date_range" => "realtime"}), do: {:ok, :realtime}
  defp parse_input_date_range(%{"date_range" => "realtime_30m"}), do: {:ok, :realtime_30m}

  defp parse_input_date_range(%{"date_range" => date_range}) do
    case ApiQueryParser.parse_input_date_range(date_range) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, %{message: message}} -> {:error, message}
    end
  end

  defp parse_input_date_range(_), do: {:error, "Required 'date_range' parameter missing"}

  defp parse_relative_date(%{"relative_date" => date}) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, date} -> {:ok, date}
      _ -> {:error, "Failed to convert '#{date}' to date"}
    end
  end

  defp parse_relative_date(_), do: {:ok, nil}

  def create(conn, params) do
    user = conn.assigns.current_user
    site = conn.assigns.site
    site_role = conn.assigns.site_role

    case Annotations.insert_one(user, site, site_role, params) do
      {:error, :not_enough_permissions} ->
        H.not_enough_permissions(conn, "Not enough permissions to create annotation")

      {:error, :annotations_limit_reached} ->
        H.not_enough_permissions(conn, "Annotations limit reached")

      {:error, {:invalid_annotation, errors}} when is_list(errors) ->
        conn
        |> put_status(400)
        |> json(%{
          error: ChangesetHelpers.serialize_first_error(errors)
        })

      {:ok, annotation} ->
        json(conn, annotation)
    end
  end

  def update(conn, params) do
    user = conn.assigns.current_user
    site = conn.assigns.site
    site_role = conn.assigns.site_role
    annotation_id = normalize_annotation_id_param(params["annotation_id"])

    case Annotations.update_one(user, site, site_role, annotation_id, params) do
      {:error, :not_enough_permissions} ->
        H.not_enough_permissions(conn, "Not enough permissions to edit annotation")

      {:error, :annotation_not_found} ->
        annotation_not_found(conn, params["annotation_id"])

      {:error, {:invalid_annotation, errors}} when is_list(errors) ->
        conn
        |> put_status(400)
        |> json(%{
          error: ChangesetHelpers.serialize_first_error(errors)
        })

      {:ok, annotation} ->
        json(conn, annotation)
    end
  end

  def delete(conn, params) do
    user = conn.assigns.current_user
    site = conn.assigns.site
    site_role = conn.assigns.site_role
    annotation_id = normalize_annotation_id_param(params["annotation_id"])

    case Annotations.delete_one(user, site, site_role, annotation_id) do
      {:error, :not_enough_permissions} ->
        H.not_enough_permissions(conn, "Not enough permissions to delete annotation")

      {:error, :annotation_not_found} ->
        annotation_not_found(conn, params["annotation_id"])

      {:ok, annotation} ->
        json(conn, annotation)
    end
  end

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
end
