defmodule PlausibleWeb.Api.ExternalSitesController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  use PlausibleWeb.Plugs.ErrorHandler

  import Plausible.Pagination

  alias Plausible.Sites
  alias Plausible.Goal
  alias Plausible.Goals
  alias Plausible.Teams
  alias PlausibleWeb.Api.Helpers, as: H

  @pagination_opts [cursor_fields: [{:id, :desc}], limit: 100, maximum_limit: 1000]

  def index(conn, params) do
    team = Teams.get(params["team_id"])
    user = conn.assigns.current_user

    page =
      user
      |> Sites.for_user_query(team)
      |> paginate(params, @pagination_opts)

    json(conn, %{
      sites: page.entries,
      meta: pagination_meta(page.metadata)
    })
  end

  def guests_index(conn, params) do
    user = conn.assigns.current_user

    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, site} <- get_site(user, site_id, [:owner, :admin, :editor, :viewer]) do
      opts = [cursor_fields: [id: :desc, inserted_at: :desc], limit: 100, maximum_limit: 1000]
      page = site |> Sites.list_guests_query() |> paginate(params, opts)

      json(conn, %{
        guests:
          Enum.map(page.entries, fn entry ->
            Map.take(entry, [:email, :role, :accepted])
          end),
        meta: pagination_meta(page.metadata)
      })
    else
      {:missing, "site_id"} ->
        H.bad_request(conn, "Parameter `site_id` is required to list goals")

      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")
    end
  end

  def goals_index(conn, params) do
    user = conn.assigns.current_user

    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, site} <- get_site(user, site_id, [:owner, :admin, :editor, :viewer]) do
      page =
        site
        |> Plausible.Goals.for_site_query()
        |> paginate(params, @pagination_opts)

      json(conn, %{
        goals:
          Enum.map(page.entries, fn goal ->
            %{
              id: goal.id,
              display_name: goal.display_name,
              goal_type: Goal.type(goal),
              event_name: goal.event_name,
              page_path: goal.page_path
            }
          end),
        meta: pagination_meta(page.metadata)
      })
    else
      {:missing, "site_id"} ->
        H.bad_request(conn, "Parameter `site_id` is required to list goals")

      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")
    end
  end

  def create_site(conn, params) do
    user = conn.assigns.current_user
    team = Plausible.Teams.get(params["team_id"])

    case Sites.create(user, params, team) do
      {:ok, %{site: site}} ->
        json(conn, site)

      {:error, _, {:over_limit, limit}, _} ->
        conn
        |> put_status(402)
        |> json(%{
          error:
            "Your account has reached the limit of #{limit} sites. To unlock more sites, please upgrade your subscription."
        })

      {:error, _, :permission_denied, _} ->
        conn
        |> put_status(403)
        |> json(%{
          error: "You can't add sites to the selected team."
        })

      {:error, _, :multiple_teams, _} ->
        conn
        |> put_status(400)
        |> json(%{
          error: "You must select a team with 'team_id' parameter."
        })

      {:error, _, changeset, _} ->
        conn
        |> put_status(400)
        |> json(serialize_errors(changeset))
    end
  end

  def get_site(conn, %{"site_id" => site_id}) do
    case get_site(conn.assigns.current_user, site_id, [:owner, :admin, :editor, :viewer]) do
      {:ok, site} ->
        json(conn, %{
          domain: site.domain,
          timezone: site.timezone,
          custom_properties: site.allowed_event_props || []
        })

      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")
    end
  end

  def delete_site(conn, %{"site_id" => site_id}) do
    case get_site(conn.assigns.current_user, site_id, [:owner]) do
      {:ok, site} ->
        {:ok, _} = Plausible.Site.Removal.run(site)
        json(conn, %{"deleted" => true})

      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")
    end
  end

  def update_site(conn, %{"site_id" => site_id} = params) do
    # for now this only allows to change the domain
    with {:ok, site} <- get_site(conn.assigns.current_user, site_id, [:owner, :admin, :editor]),
         {:ok, site} <- Plausible.Site.Domain.change(site, params["domain"]) do
      json(conn, site)
    else
      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(400)
        |> json(serialize_errors(changeset))
    end
  end

  def find_or_create_guest(conn, params) do
    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, email} <- expect_param_key(params, "email"),
         {:ok, role} <- expect_param_key(params, "role", ["viewer", "editor"]),
         {:ok, site} <- get_site(conn.assigns.current_user, site_id, [:owner, :admin]) do
      existing = Repo.one(Sites.list_guests_query(site, email: email))

      if existing do
        json(conn, %{
          role: existing.role,
          email: existing.email,
          accepted: existing.accepted
        })
      else
        case Plausible.Site.Memberships.CreateInvitation.create_invitation(
               site,
               conn.assigns.current_user,
               email,
               role
             ) do
          {:ok, invitation} ->
            json(conn, %{
              role: invitation.role,
              email: invitation.team_invitation.email,
              accepted: false
            })
        end
      end
    else
      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")

      {:missing, "role"} ->
        H.bad_request(
          conn,
          "Parameter `role` is required to create guest. Possible values: `viewer` or `editor`"
        )

      {:missing, param} ->
        H.bad_request(conn, "Parameter `#{param}` is required to create guest")
    end
  end

  def find_or_create_shared_link(conn, params) do
    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, link_name} <- expect_param_key(params, "name"),
         {:ok, site} <- get_site(conn.assigns.current_user, site_id, [:owner, :admin, :editor]) do
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
      {:error, :site_not_found} ->
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
         {:ok, site} <- get_site(conn.assigns.current_user, site_id, [:owner, :admin, :editor]),
         {:ok, goal} <- Goals.find_or_create(site, params) do
      json(conn, goal)
    else
      {:error, :site_not_found} ->
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
         {:ok, site} <- get_site(conn.assigns.current_user, site_id, [:owner, :admin, :editor]),
         :ok <- Goals.delete(goal_id, site) do
      json(conn, %{"deleted" => true})
    else
      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")

      {:error, :not_found} ->
        H.not_found(conn, "Goal could not be found")

      {:missing, "site_id"} ->
        H.bad_request(conn, "Parameter `site_id` is required to delete a goal")

      {:missing, "goal_id"} ->
        H.bad_request(conn, "Parameter `goal_id` is required to delete a goal")

      e ->
        H.bad_request(conn, "Something went wrong: #{inspect(e)}")
    end
  end

  defp pagination_meta(meta) do
    %{
      after: meta.after,
      before: meta.before,
      limit: meta.limit
    }
  end

  defp get_site(user, site_id, roles) do
    case Plausible.Sites.get_for_user(user, site_id, roles) do
      nil -> {:error, :site_not_found}
      site -> {:ok, site}
    end
  end

  defp serialize_errors(changeset) do
    {field, {msg, _opts}} = List.first(changeset.errors)
    error_msg = Atom.to_string(field) <> ": " <> msg
    %{"error" => error_msg}
  end

  defp expect_param_key(params, key, inclusion \\ []) do
    case Map.get(params, key) do
      nil ->
        {:missing, key}

      res ->
        if Enum.empty?(inclusion) do
          {:ok, res}
        else
          if res in inclusion do
            {:ok, res}
          else
            {:missing, key}
          end
        end
    end
  end
end
