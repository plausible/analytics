defmodule Plausible.SiteAdmin do
  use Plausible.Repo

  import Ecto.Query

  def ordering(_schema) do
    [desc: :inserted_at]
  end

  def search_fields(_schema) do
    [
      :domain
    ]
  end

  def custom_index_query(conn, _schema, query) do
    search =
      (conn.params["custom_search"] || "")
      |> String.trim()
      |> String.replace("%", "\%")
      |> String.replace("_", "\_")

    search_term = "%#{search}%"

    member_query =
      from s in Plausible.Site,
        left_join: gm in assoc(s, :guest_memberships),
        left_join: tm in assoc(gm, :team_membership),
        left_join: u in assoc(tm, :user),
        where: s.id == parent_as(:site).id,
        where: ilike(u.email, ^search_term) or ilike(u.name, ^search_term),
        select: 1

    from(r in query,
      as: :site,
      inner_join: o in assoc(r, :owners),
      inner_join: t in assoc(r, :team),
      preload: [owners: o, team: t, guest_memberships: [team_membership: :user]],
      or_where: ilike(t.name, ^search_term),
      or_where: ilike(r.domain, ^search_term),
      or_where: ilike(o.email, ^search_term),
      or_where: ilike(o.name, ^search_term),
      or_where: exists(member_query)
    )
  end

  def before_update(_conn, changeset) do
    if Ecto.Changeset.get_change(changeset, :native_stats_start_at) do
      {:ok, Ecto.Changeset.put_change(changeset, :stats_start_date, nil)}
    else
      {:ok, changeset}
    end
  end

  def form_fields(_) do
    [
      domain: %{update: :readonly},
      timezone: %{choices: Plausible.Timezones.options()},
      public: nil,
      native_stats_start_at: %{
        type: :string,
        label: "Native stats start time",
        help_text:
          "Cutoff time for native stats in UTC timezone. Expected format: YYYY-MM-DDTHH:mm:ss"
      },
      ingest_rate_limit_scale_seconds: %{
        help_text: "Time scale for which events rate-limiting is calculated. Default: 60"
      },
      ingest_rate_limit_threshold: %{
        help_text:
          "Keep empty to disable rate limiting, set to 0 to bar all events. Any positive number sets the limit."
      }
    ]
  end

  def index(_) do
    [
      domain: nil,
      inserted_at: %{name: "Created at", value: &format_date(&1.inserted_at)},
      timezone: nil,
      public: nil,
      team: %{value: &get_team/1},
      owners: %{value: &get_owners/1},
      other_members: %{value: &get_other_members/1},
      limits: %{
        value: fn site ->
          rate_limiting_status =
            case site.ingest_rate_limit_threshold do
              nil -> ""
              0 -> "🛑 BLOCKED"
              n -> "⏱ #{n}/#{site.ingest_rate_limit_scale_seconds}s (per server)"
            end

          team_limits =
            if site.team.accept_traffic_until &&
                 Date.after?(Date.utc_today(), site.team.accept_traffic_until) do
              "💸 Rejecting traffic"
            end

          {:safe, Enum.join([rate_limiting_status, team_limits], "<br/><br/>")}
        end
      }
    ]
  end

  def list_actions(_conn) do
    [
      transfer_ownership: %{
        name: "Transfer ownership",
        inputs: [
          %{name: "email", title: "New Owner Email", default: nil}
        ],
        action: fn conn, sites, params -> transfer_ownership(conn, sites, params) end
      },
      transfer_ownership_direct: %{
        name: "Transfer ownership without invite",
        inputs: [
          %{name: "email", title: "New Owner Email", default: nil}
        ],
        action: fn conn, sites, params -> transfer_ownership_direct(conn, sites, params) end
      }
    ]
  end

  defp transfer_ownership(_conn, [], _params) do
    {:error, "Please select at least one site from the list"}
  end

  defp transfer_ownership(conn, sites, %{"email" => email}) do
    inviter = conn.assigns.current_user

    with {:ok, new_owner} <- Plausible.Auth.get_user_by(email: email),
         {:ok, _} <-
           Plausible.Site.Memberships.bulk_create_invitation(
             sites,
             inviter,
             new_owner.email,
             :owner,
             check_permissions: false
           ) do
      :ok
    else
      {:error, :user_not_found} ->
        {:error, "User could not be found"}

      {:error, :transfer_to_self} ->
        {:error, "User is already an owner of one of the sites"}
    end
  end

  defp transfer_ownership_direct(_conn, [], _params) do
    {:error, "Please select at least one site from the list"}
  end

  defp transfer_ownership_direct(_conn, sites, %{"email" => email} = params) do
    team = Plausible.Teams.get(params["team_id"])

    with {:ok, new_owner} <- Plausible.Auth.get_user_by(email: email),
         {:ok, _} <-
           Plausible.Site.Memberships.bulk_transfer_ownership_direct(
             sites,
             new_owner,
             team
           ) do
      :ok
    else
      {:error, :user_not_found} ->
        {:error, "User could not be found"}

      {:error, :transfer_to_self} ->
        {:error, "User is already an owner of one of the sites"}

      {:error, :no_plan} ->
        {:error, "The new owner does not have a subscription"}

      {:error, :multiple_teams} ->
        {:error, "The new owner owns more than one team"}

      {:error, :permission_denied} ->
        {:error, "The new owner can't add sites in the selected team"}

      {:error, {:over_plan_limits, limits}} ->
        {:error, "Plan limits exceeded for one of the sites: #{Enum.join(limits, ", ")}"}
    end
  end

  defp format_date(date) do
    Calendar.strftime(date, "%b %-d, %Y")
  end

  defp get_team(site) do
    team_name =
      case site.owners do
        [owner] ->
          if site.team.name == "My Team" do
            owner.name
          else
            site.team.name
          end

        [_ | _] ->
          site.team.name
      end
      |> html_escape()

    """
    <a href="/crm/teams/team/#{site.team.id}">#{team_name}</a>
    """
    |> Phoenix.HTML.raw()
  end

  defp get_owners(site) do
    owners_html =
      Enum.map(site.owners, fn owner ->
        escaped_name = html_escape(owner.name)
        escaped_email = html_escape(owner.email)

        """
         <a href="/crm/auth/user/#{owner.id}">#{escaped_name}</a>
         <br/>
         #{escaped_email}
        """
      end)

    {:safe, Enum.join(owners_html, "<br/><br/>")}
  end

  defp get_other_members(site) do
    site.guest_memberships
    |> Enum.map_join(", ", fn m ->
      id = m.team_membership.user.id
      email = html_escape(m.team_membership.user.email)
      role = html_escape(m.role)

      """
      <a href="/auth/user/#{id}">#{email} (#{role})</a>
      """
    end)
    |> Phoenix.HTML.raw()
  end

  def get_struct_fields(module) do
    module.__struct__()
    |> Map.drop([:__meta__, :__struct__])
    |> Map.keys()
    |> Enum.map(&Atom.to_string/1)
    |> Enum.sort()
  end

  def create_changeset(schema, attrs), do: Plausible.Site.crm_changeset(schema, attrs)
  def update_changeset(schema, attrs), do: Plausible.Site.crm_changeset(schema, attrs)

  def html_escape(string) do
    string
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
