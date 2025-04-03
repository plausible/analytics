defmodule PlausibleWeb.Site.MembershipController do
  @moduledoc """
    This controller deals with user management via the UI in Site Settings -> People. It's important to enforce permissions in this controller.

    Owner and Admin - Can manage users, can trigger a 'transfer ownership' request
    Editor and Viewer - Can not access user management settings
    Anyone - Can accept invitations

    Everything else should be explicitly disallowed.
  """

  use PlausibleWeb, :controller
  use Plausible.Repo
  use Plausible
  alias Plausible.Site.Memberships

  plug PlausibleWeb.RequireAccountPlug

  plug PlausibleWeb.Plugs.AuthorizeSiteAccess, [:owner, :admin]

  def invite_member_form(conn, _params) do
    site =
      conn.assigns.current_user
      |> Plausible.Sites.get_for_user!(conn.assigns.site.domain)
      |> Plausible.Repo.preload(:owners)

    limit = Plausible.Teams.Billing.team_member_limit(site.team)
    usage = Plausible.Teams.Billing.team_member_usage(site.team)
    below_limit? = Plausible.Billing.Quota.below_limit?(usage, limit)

    render(
      conn,
      "invite_member_form.html",
      site: site,
      team_member_limit: limit,
      is_at_limit: not below_limit?,
      skip_plausible_tracking: true
    )
  end

  def invite_member(conn, %{"email" => email, "role" => role}) do
    site_domain = conn.assigns.site.domain

    site =
      Plausible.Sites.get_for_user!(conn.assigns.current_user, site_domain)
      |> Plausible.Repo.preload(:owners)

    case Memberships.create_invitation(site, conn.assigns.current_user, email, role) do
      {:ok, invitation} ->
        conn
        |> put_flash(
          :success,
          "#{email} has been invited to #{site_domain} as #{PlausibleWeb.SiteView.with_indefinite_article("#{invitation.role}")}"
        )
        |> redirect(external: Routes.site_path(conn, :settings_people, site.domain))

      {:error, :already_a_member} ->
        render(conn, "invite_member_form.html",
          error: "Cannot send invite because #{email} is already a member of #{site.domain}",
          site: site,
          skip_plausible_tracking: true
        )

      {:error, {:over_limit, limit}} ->
        render(conn, "invite_member_form.html",
          error:
            "Your account is limited to #{limit} team members. You can upgrade your plan to increase this limit.",
          site: site,
          skip_plausible_tracking: true,
          is_at_limit: true,
          team_member_limit: limit
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        error_msg =
          case changeset.errors[:invitation] do
            {"already sent", _} ->
              "This invitation has been already sent. To send again, remove it from pending invitations first."

            _ ->
              "Something went wrong."
          end

        conn
        |> put_flash(:error, error_msg)
        |> redirect(external: Routes.site_path(conn, :settings_people, site.domain))
    end
  end

  def transfer_ownership_form(conn, _params) do
    site_domain = conn.assigns.site.domain

    site =
      Plausible.Sites.get_for_user!(conn.assigns.current_user, site_domain)

    render(
      conn,
      "transfer_ownership_form.html",
      site: site,
      skip_plausible_tracking: true
    )
  end

  def transfer_ownership(conn, %{"email" => email}) do
    site_domain = conn.assigns.site.domain

    site =
      Plausible.Sites.get_for_user!(conn.assigns.current_user, site_domain)

    case Memberships.create_invitation(site, conn.assigns.current_user, email, :owner) do
      {:ok, _invitation} ->
        conn
        |> put_flash(:success, "Site transfer request has been sent to #{email}")
        |> redirect(external: Routes.site_path(conn, :settings_people, site.domain))

      {:error, changeset} ->
        errors = Plausible.ChangesetHelpers.traverse_errors(changeset)

        message =
          case errors do
            %{invitation: ["already sent" | _]} -> "Invitation has already been sent"
            _other -> "Site transfer request to #{email} has failed"
          end

        conn
        |> put_flash(:ttl, :timer.seconds(5))
        |> put_flash(:error_title, "Transfer error")
        |> put_flash(:error, message)
        |> redirect(external: Routes.site_path(conn, :settings_people, site.domain))
    end
  end

  def change_team_form(conn, _params) do
    site_domain = conn.assigns.site.domain
    user = conn.assigns.current_user

    site =
      Plausible.Sites.get_for_user!(user, site_domain)

    render_change_team_form(conn, user, site)
  end

  defp render_change_team_form(conn, user, site, opts \\ []) do
    transferable_teams =
      user
      |> Plausible.Teams.Users.teams(roles: [:owner, :admin])
      |> Enum.reject(&(&1.id == site.team_id))
      |> Enum.map(&{&1.name, &1.identifier})

    render(
      conn,
      "change_team_form.html",
      site: site,
      skip_plausible_tracking: true,
      transferable_teams: transferable_teams,
      error: opts[:error]
    )
  end

  def change_team(conn, %{"team_identifier" => identifier}) do
    site_domain = conn.assigns.site.domain
    user = conn.assigns.current_user

    site =
      Plausible.Sites.get_for_user!(user, site_domain)

    destination_team =
      Repo.one!(
        Plausible.Teams.Users.teams_query(user, roles: [:admin, :owner], identifier: identifier)
      )

    case Memberships.AcceptInvitation.change_team(
           site,
           conn.assigns.current_user,
           destination_team
         ) do
      :ok ->
        conn
        |> put_flash(:success, "Site team was changed")
        |> redirect(external: Routes.site_path(conn, :index, __team: identifier))

      {:error, :no_plan} ->
        conn
        |> render_change_team_form(conn.assigns.current_user, site,
          error: "This team has no subscription"
        )

      {:error, {:over_plan_limits, _}} ->
        conn
        |> render_change_team_form(conn.assigns.current_user, site,
          error: "This team's subscription outgrows site usage"
        )

      {:error, _} ->
        conn
        |> render_change_team_form(conn.assigns.current_user, site,
          error: "Sorry, this team cannot be used"
        )
    end
  end

  @doc """
    Updates the role of a user. The user being updated could be the same or different from the user taking
    the action. When updating the role, it's important to enforce permissions:

    Owner - Can update anyone's role except for themselves. If they want to change their own role, they have to use the 'transfer ownership' feature.
    Admin - Can update anyone's role except for owners. Can downgrade their own access to 'viewer'. Can promote a viewer to admin.
  """
  def update_role_by_user(conn, %{"id" => user_id, "new_role" => new_role_str}) do
    %{site: site, current_user: current_user, site_role: site_role} = conn.assigns

    case Plausible.Teams.Memberships.update_role(
           site,
           user_id,
           new_role_str,
           current_user,
           site_role
         ) do
      {:ok, guest_membership} ->
        redirect_target =
          if guest_membership.team_membership.user_id == current_user.id and
               guest_membership.role == :viewer do
            "/#{URI.encode_www_form(site.domain)}"
          else
            Routes.site_path(conn, :settings_people, site.domain)
          end

        conn
        |> put_flash(
          :success,
          "#{guest_membership.team_membership.user.name} is now #{PlausibleWeb.SiteView.with_indefinite_article(to_string(guest_membership.role))}"
        )
        |> redirect(external: redirect_target)

      {:error, _} ->
        conn
        |> put_flash(:error, "You are not allowed to grant the #{new_role_str} role")
        |> redirect(external: Routes.site_path(conn, :settings_people, site.domain))
    end
  end

  def remove_member_by_user(conn, %{"id" => user_id} = _params) do
    site = conn.assigns.site

    if user = Repo.get(Plausible.Auth.User, user_id) do
      Plausible.Teams.Memberships.remove(site, user)

      redirect_target =
        if user_id == conn.assigns[:current_user].id do
          "/#{URI.encode_www_form(site.domain)}"
        else
          Routes.site_path(conn, :settings_people, site.domain)
        end

      conn
      |> put_flash(
        :success,
        "#{user.name} has been removed from #{site.domain}"
      )
      |> redirect(external: redirect_target)
    else
      conn
      |> put_flash(
        :success,
        "User has been removed from #{site.domain}"
      )
      |> redirect(external: Routes.site_path(conn, :settings_people, site.domain))
    end
  end
end
