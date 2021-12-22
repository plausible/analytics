defmodule PlausibleWeb.Api.ExternalSitesController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  use Plug.ErrorHandler
  alias Plausible.Sites
  alias Plausible.Goals
  alias PlausibleWeb.Api.Helpers, as: H

  def create_site(conn, params) do
    user = conn.assigns[:current_user]

    case Sites.create(user, params) do
      {:ok, %{site: site}} ->
        json(conn, site)

      {:error, :site, changeset, _} ->
        conn
        |> put_status(400)
        |> json(serialize_errors(changeset))

      {:error, :limit, limit} ->
        conn
        |> put_status(403)
        |> json(%{
          error:
            "Your account has reached the limit of #{limit} sites per account. Please contact hello@plausible.io to unlock more sites."
        })
    end
  end

  def delete_site(conn, %{"site_id" => site_id}) do
    site = Sites.get_for_user(conn.assigns[:current_user].id, site_id, [:owner])

    if site do
      Sites.delete!(site)
      json(conn, %{"deleted" => true})
    else
      H.not_found(conn, "Site could not be found")
    end
  end

  defp expect_param_key(params, key) do
    case Map.fetch(params, key) do
      :error -> {:missing, key}
      res -> res
    end
  end

  def find_or_create_shared_link(conn, params) do
    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, link_name} <- expect_param_key(params, "name"),
         site when not is_nil(site) <-
           Sites.get_for_user(conn.assigns[:current_user].id, site_id, [:owner, :admin]) do
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
        H.not_found(conn, "Site could not be found")

      {:missing, "site_id"} ->
        H.bad_request(conn, "Parameter `site_id` is required to create a shared link")

      {:missing, "name"} ->
        H.bad_request(conn, "Parameter `name` is required to create a shared link")

      e ->
        H.bad_request(conn, "Something went wrong: #{inspect(e)}")
    end
  end

  def find_or_create_goal(conn, params) do
    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, _} <- expect_param_key(params, "goal_type"),
         site when not is_nil(site) <-
           Sites.get_for_user(conn.assigns[:current_user].id, site_id, [:owner, :admin]),
         {:ok, goal} <- Goals.find_or_create(site, params) do
      json(conn, goal)
    else
      nil ->
        H.not_found(conn, "Site could not be found")

      {:missing, param} ->
        H.bad_request(conn, "Parameter `#{param}` is required to create a goal")

      e ->
        H.bad_request(conn, "Something went wrong: #{inspect(e)}")
    end
  end

  def delete_goal(conn, params) do
    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, goal_id} <- expect_param_key(params, "goal_id"),
         site when not is_nil(site) <-
           Sites.get_for_user(conn.assigns[:current_user].id, site_id, [:owner, :admin]) do
      goal = Repo.get_by(Plausible.Goal, id: goal_id)

      if goal do
        Goals.delete(goal_id)
        json(conn, %{"deleted" => true})
      else
        H.not_found(conn, "Goal could not be found")
      end
    else
      nil ->
        H.not_found(conn, "Site could not be found")

      {:missing, "site_id"} ->
        H.bad_request(conn, "Parameter `site_id` is required to delete a goal")

      {:missing, "goal_id"} ->
        H.bad_request(conn, "Parameter `goal_id` is required to delete a goal")

      e ->
        H.bad_request(conn, "Something went wrong: #{inspect(e)}")
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
