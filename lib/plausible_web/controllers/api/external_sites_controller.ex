defmodule PlausibleWeb.Api.ExternalSitesController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  use Plug.ErrorHandler
  alias Plausible.Sites

  def create_site(conn, params) do
    user_id = conn.assigns[:current_user_id]

    case Sites.create(user_id, params) do
      {:ok, %{site: site}} ->
        json(conn, site)

      {:error, :site, changeset, _} ->
        conn
        |> put_status(400)
        |> json(serialize_errors(changeset))
    end
  end

  def find_or_create_shared_link(conn, %{"link_name" => link_name} = params) do
    with {:ok, site_id} <- Map.fetch(params, "site_id"),
         site when not is_nil(site) <- Sites.get_for_user(conn.assigns[:current_user_id], site_id) do
      shared_link = Repo.get_by(Plausible.Site.SharedLink, site_id: site.id, name: link_name)

      shared_link =
        case shared_link do
          nil -> Sites.create_shared_link(site, link_name)
          link -> {:ok, link}
        end

      case shared_link do
        {:ok, link} ->
          json(conn, %{
            name: link.name,
            url: Sites.shared_link_url(site, link)
          })
      end
    else
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "Site could not be found"})

      :error ->
        conn
        |> put_status(400)
        |> json(%{error: "Query parameter `site_id` is required to create a shared link"})

      e ->
        conn
        |> put_status(400)
        |> json(%{error: "Something went wrong: #{inspect(e)}"})
    end
  end

  defp serialize_errors(changeset) do
    {field, {msg, _opts}} = List.first(changeset.errors)
    error_msg = Atom.to_string(field) <> " " <> msg
    %{"error" => error_msg}
  end

  def handle_errors(conn, %{kind: kind, reason: reason}) do
    json(conn, %{error: Exception.format_banner(kind, reason)})
  end
end
