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
    user = conn.assigns.current_user
    team = conn.assigns.current_team || Teams.get(params["team_id"])

    page =
      user
      |> Sites.for_user_query(team)
      |> paginate(params, @pagination_opts)

    json(conn, %{
      sites: page.entries |> Enum.map(&get_site_response_for_index/1),
      meta: pagination_meta(page.metadata)
    })
  end

  def guests_index(conn, params) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, site} <- find_site(user, team, site_id, [:owner, :admin, :editor, :viewer]) do
      opts = [cursor_fields: [inserted_at: :desc, id: :desc], limit: 100, maximum_limit: 1000]
      page = site |> Sites.list_guests_query() |> paginate(params, opts)

      json(conn, %{
        guests:
          Enum.map(page.entries, fn entry ->
            Map.take(entry, [:email, :role, :status])
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

  def teams_index(conn, params) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    page =
      user
      |> Teams.Users.teams_query(identifier: team && team.identifier, order_by: :id_desc)
      |> paginate(params, @pagination_opts)

    json(conn, %{
      teams:
        Enum.map(page.entries, fn team ->
          api_available? =
            Plausible.Billing.Feature.StatsAPI.check_availability(team) == :ok

          %{
            id: team.identifier,
            name: Teams.name(team),
            api_available: api_available?
          }
        end),
      meta: pagination_meta(page.metadata)
    })
  end

  def goals_index(conn, params) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, site} <- find_site(user, team, site_id, [:owner, :admin, :editor, :viewer]) do
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
    team = conn.assigns.current_team || Teams.get(params["team_id"])

    case Repo.transact(fn ->
           with {:ok, %{site: site}} <- Sites.create(user, params, team),
                {:ok, tracker_script_configuration} <-
                  get_or_create_config(site, params["tracker_script_configuration"] || %{}, user) do
             {:ok,
              struct(site,
                tracker_script_configuration: tracker_script_configuration
              )}
           else
             # Translates Multi error format to Repo.transact error format
             {:error, step_id, output, context} ->
               {:error, {step_id, output, context}}

             # already in Repo.transact error format
             {:error, reason} ->
               {:error, reason}
           end
         end) do
      {:ok, site} ->
        json(conn, get_site_response(site, user))

      {:error, {_, {:over_limit, limit}, _}} ->
        conn
        |> put_status(402)
        |> json(%{
          error:
            "Your account has reached the limit of #{limit} sites. To unlock more sites, please upgrade your subscription."
        })

      {:error, {_, :permission_denied, _}} ->
        conn
        |> put_status(403)
        |> json(%{
          error: "You can't add sites to the selected team."
        })

      {:error, {_, :multiple_teams, _}} ->
        conn
        |> put_status(400)
        |> json(%{
          error: "You must select a team with 'team_id' parameter."
        })

      {:error, {:tracker_script_configuration_invalid, %Ecto.Changeset{} = changeset}} ->
        conn
        |> put_status(400)
        |> json(serialize_errors(changeset, "tracker_script_configuration."))

      {:error, {_, %Ecto.Changeset{} = changeset, _}} ->
        conn
        |> put_status(400)
        |> json(serialize_errors(changeset))
    end
  end

  def get_site(conn, %{"site_id" => site_id}) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    with {:ok, site} <- find_site(user, team, site_id, [:owner, :admin, :editor, :viewer]),
         {:ok, tracker_script_configuration} <- get_or_create_config(site, %{}, user) do
      site = struct(site, tracker_script_configuration: tracker_script_configuration)

      json(
        conn,
        get_site_response(
          site,
          user
        )
      )
    else
      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")
    end
  end

  def delete_site(conn, %{"site_id" => site_id}) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    case find_site(user, team, site_id, [:owner]) do
      {:ok, site} ->
        {:ok, _} = Plausible.Site.Removal.run(site)
        json(conn, %{"deleted" => true})

      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")
    end
  end

  def update_site(conn, %{"site_id" => site_id} = params) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    with {:ok, params} <- validate_update_payload(params),
         {:ok, site} <- find_site(user, team, site_id, [:owner, :admin, :editor]),
         {:ok, site} <- do_update_site(site, params, user) do
      json(conn, get_site_response(site, user))
    else
      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")

      {:error, :no_changes} ->
        H.bad_request(
          conn,
          "Payload must contain at least one of the parameters 'domain', 'tracker_script_configuration'"
        )

      {:error, {:domain_change_invalid, %Ecto.Changeset{} = changeset}} ->
        conn
        |> put_status(400)
        |> json(serialize_errors(changeset))

      {:error, {:tracker_script_configuration_invalid, %Ecto.Changeset{} = changeset}} ->
        conn
        |> put_status(400)
        |> json(serialize_errors(changeset, "tracker_script_configuration."))
    end
  end

  defp validate_update_payload(params) do
    params = params |> Map.take(["domain", "tracker_script_configuration"]) |> Map.drop([nil])

    if map_size(params) == 0 do
      {:error, :no_changes}
    else
      {:ok, params}
    end
  end

  defp do_update_site(site, params, user) do
    Repo.transact(fn ->
      with {:ok, site} <-
             if(params["domain"],
               do: change_domain(site, params["domain"]),
               else: {:ok, site}
             ),
           {:ok, tracker_script_configuration} <-
             if(params["tracker_script_configuration"],
               do: update_config(site, params["tracker_script_configuration"], user),
               else: get_or_create_config(site, %{}, user)
             ) do
        {:ok, struct(site, tracker_script_configuration: tracker_script_configuration)}
      end
    end)
  end

  defp change_domain(site, domain) do
    case Plausible.Site.Domain.change(site, domain) do
      {:ok, site} ->
        {:ok, site}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, {:domain_change_invalid, changeset}}
    end
  end

  def find_or_create_guest(conn, params) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, email} <- expect_param_key(params, "email"),
         {:ok, role} <- expect_param_key(params, "role", ["viewer", "editor"]),
         {:ok, site} <- find_site(user, team, site_id, [:owner, :admin]) do
      existing = Repo.one(Sites.list_guests_query(site, email: email))

      if existing do
        json(conn, %{
          role: existing.role,
          email: existing.email,
          status: existing.status
        })
      else
        case Teams.Invitations.InviteToSite.invite(
               site,
               conn.assigns.current_user,
               email,
               role
             ) do
          {:ok, invitation} ->
            json(conn, %{
              role: invitation.role,
              email: invitation.team_invitation.email,
              status: "invited"
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

  def delete_guest(conn, params) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, email} <- expect_param_key(params, "email"),
         {:ok, site} <- find_site(user, team, site_id, [:owner, :admin]) do
      existing = Repo.one(Sites.list_guests_query(site, email: email))

      case existing do
        %{status: "invited", id: id} ->
          with guest_invitation when not is_nil(guest_invitation) <-
                 Repo.get(Teams.GuestInvitation, id) do
            Teams.Invitations.remove_guest_invitation(guest_invitation)
          end

        %{status: "accepted", email: email} ->
          with %{} = user <- Repo.get_by(Plausible.Auth.User, email: email) do
            Teams.Memberships.remove(site, user)
          end

        _ ->
          :ignore
      end

      json(conn, %{"deleted" => true})
    else
      {:error, :site_not_found} ->
        H.not_found(conn, "Site could not be found")

      {:missing, param} ->
        H.bad_request(conn, "Parameter `#{param}` is required to delete a guest")
    end
  end

  def find_or_create_shared_link(conn, params) do
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, link_name} <- expect_param_key(params, "name"),
         {:ok, site} <- find_site(user, team, site_id, [:owner, :admin, :editor]) do
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

        {:error, %Ecto.Changeset{} = changeset} ->
          {msg, _} = changeset.errors[:name]
          H.bad_request(conn, msg)

        {:error, :upgrade_required} ->
          H.payment_required(conn, "Your current subscription plan does not include Shared Links")
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
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, _} <- expect_param_key(params, "goal_type"),
         {:ok, site} <- find_site(user, team, site_id, [:owner, :admin, :editor]),
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
    user = conn.assigns.current_user
    team = conn.assigns.current_team

    with {:ok, site_id} <- expect_param_key(params, "site_id"),
         {:ok, goal_id} <- expect_param_key(params, "goal_id"),
         {:ok, site} <- find_site(user, team, site_id, [:owner, :admin, :editor]),
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

  defp find_site(user, team, site_id, roles) do
    case Plausible.Sites.get_for_user(user, site_id, roles) do
      nil ->
        {:error, :site_not_found}

      site ->
        site = Repo.preload(site, :team)

        if team && team.id != site.team_id do
          {:error, :site_not_found}
        else
          {:ok, site}
        end
    end
  end

  defp serialize_errors(changeset, field_prefix \\ "") do
    {field, {msg, _opts}} = List.first(changeset.errors)
    error_msg = field_prefix <> Atom.to_string(field) <> ": " <> msg
    %{"error" => error_msg}
  end

  defp expect_param_key(params, key, inclusion \\ [])

  defp expect_param_key(params, key, []) do
    case Map.fetch(params, key) do
      :error -> {:missing, key}
      res -> res
    end
  end

  defp expect_param_key(params, key, inclusion) do
    case expect_param_key(params, key, []) do
      {:ok, value} = ok ->
        if value in inclusion, do: ok, else: {:missing, key}

      _ ->
        {:missing, key}
    end
  end

  defp get_or_create_config(site, params, user) do
    if PlausibleWeb.Tracker.scriptv2?(site, user) do
      case PlausibleWeb.Tracker.get_or_create_tracker_script_configuration(site, params) do
        {:ok, tracker_script_configuration} ->
          {:ok, tracker_script_configuration}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:error, {:tracker_script_configuration_invalid, changeset}}
      end
    else
      {:ok, %{}}
    end
  end

  defp update_config(site, params, user) do
    if PlausibleWeb.Tracker.scriptv2?(site, user) do
      case PlausibleWeb.Tracker.update_script_configuration(site, params, :installation) do
        {:ok, tracker_script_configuration} ->
          {:ok, tracker_script_configuration}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:error, {:tracker_script_configuration_invalid, changeset}}
      end
    else
      {:ok, %{}}
    end
  end

  defp get_site_response_for_index(site) do
    site |> Map.take([:domain, :timezone])
  end

  defp get_site_response(site, user) do
    serializable_properties =
      if(PlausibleWeb.Tracker.scriptv2?(site, user),
        do: [:domain, :timezone, :tracker_script_configuration],
        else: [:domain, :timezone]
      )

    site
    |> Map.take(serializable_properties)
    # remap to `custom_properties`
    |> Map.put(:custom_properties, site.allowed_event_props || [])
  end
end
