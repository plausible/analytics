defmodule PlausibleWeb.Api.ExternalSitesController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  use Plug.ErrorHandler
  alias Plausible.Sites

  def create_site(conn, params) do
    user_id = conn.assigns[:current_user_id]
    site_params = Map.get(params, "site", %{})

    case Sites.create(user_id, site_params) do
      {:ok, %{site: site}} ->
        json(conn, site)

      {:error, :site, changeset, _} ->
        conn
        |> put_status(400)
        |> json(serialize_errors(changeset))
    end
  end

  def find_or_create_shared_link(conn, %{"domain" => domain, "link_name" => link_name}) do
    site = Sites.get_for_user!(conn.assigns[:current_user_id], domain)
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
