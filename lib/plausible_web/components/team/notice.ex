defmodule PlausibleWeb.Team.Notice do
  @moduledoc """
  Components with teams related notices.
  """
  use PlausibleWeb, :component
  import PlausibleWeb.Components.Icons

  alias Plausible.Teams

  def owner_cta_banner(assigns) do
    ~H"""
    <aside class="mt-4 mb-4">
      <.notice
        title="A Better Way of Inviting People to Your Team"
        class="shadow-md dark:shadow-none mt-4"
      >
        <p>
          You can also create a team and assign different roles to team members, such as admin,
          editor, viewer or billing. Team members will gain access to all your sites. <.styled_link href={
            Routes.team_setup_path(PlausibleWeb.Endpoint, :setup)
          }>
            Create your team here
          </.styled_link>.
        </p>
      </.notice>
    </aside>
    """
  end

  def guest_cta_banner(assigns) do
    ~H"""
    <aside class="mt-4 mb-4">
      <.notice
        title="A Better Way of Inviting People to a Team"
        class="shadow-md dark:shadow-none mt-4"
      >
        <p>
          It is also possible to create a team and assign different roles to team members, such as
          admin, editor, viewer or billing. Team members can gain access to all the sites. Please
          contact the site owner to create your team.
        </p>
      </.notice>
    </aside>
    """
  end

  def team_members_notice(assigns) do
    ~H"""
    <aside class="mt-4 mb-4">
      <.notice theme={:gray} class="mt-4">
        <p>
          Team members automatically have access to this site.
          <.styled_link href={Routes.settings_path(PlausibleWeb.Endpoint, :team_general)}>
            View team members
          </.styled_link>
        </p>
      </.notice>
    </aside>
    """
  end

  def team_invitations(assigns) do
    ~H"""
    <aside :if={not Enum.empty?(@team_invitations)} class="flex flex-col gap-y-4">
      <.notice
        :for={i <- @team_invitations}
        id={"invitation-#{i.invitation_id}"}
        title="Team invitation"
        theme={:white}
      >
        <:icon>
          <div class="shrink-0 -mt-1 bg-green-100/80 dark:bg-green-900/30 rounded-lg p-1.5">
            <.envelope_icon class="size-4 text-green-600 dark:text-green-400" />
          </div>
        </:icon>
        {i.inviter.name} has invited you to join the "{i.team.name}" as {i.role} member.
        <:actions>
          <.button_link
            method="post"
            href={Routes.invitation_path(PlausibleWeb.Endpoint, :reject_invitation, i.invitation_id)}
            phx-value-invitation-id={i.invitation_id}
            theme="ghost"
            size="sm"
            class="order-2 md:order-1"
            mt?={false}
          >
            Reject
          </.button_link>
          <.button_link
            method="post"
            href={Routes.invitation_path(PlausibleWeb.Endpoint, :accept_invitation, i.invitation_id)}
            theme="secondary"
            size="sm"
            class="order-1 md:order-2"
            mt?={false}
          >
            Accept
          </.button_link>
        </:actions>
      </.notice>
    </aside>
    """
  end

  def site_ownership_invitations(assigns) do
    ~H"""
    <aside :if={not Enum.empty?(@site_ownership_invitations)} class="flex flex-col gap-y-4">
      <.site_ownership_invitation
        :for={i <- @site_ownership_invitations}
        invitation={i}
        current_team={@current_team}
      />
    </aside>
    """
  end

  defp site_ownership_invitation(assigns) do
    assigns =
      assign(assigns, :can_accept?, assigns.invitation.ownership_check == :ok)

    assigns =
      assign(
        assigns,
        :exceeded_limits,
        case assigns.invitation.ownership_check do
          {:error, {:over_plan_limits, limits}} ->
            PlausibleWeb.TextHelpers.pretty_list(limits)

          _ ->
            nil
        end
      )

    ~H"""
    <.notice
      id={"site-ownership-invitation-#{@invitation.transfer_id}"}
      title={"Become owner of #{@invitation.site.domain}"}
      theme={:white}
    >
      <:icon>
        <div class="shrink-0 -mt-1 bg-green-100/80 dark:bg-green-900/30 rounded-lg p-1.5">
          <.envelope_icon class="size-4 text-green-600 dark:text-green-400" />
        </div>
      </:icon>
      {@invitation.initiator.name} has invited you to own {@invitation.site.domain}.
      <p :if={@invitation.ownership_check == :ok}>
        On acceptance, you'll be responsible for billing and this site will join "{Teams.name(
          @current_team
        )}"
      </p>
      <p :if={@invitation.ownership_check == {:error, :no_plan}} class="text-sm font-medium">
        You don't have an active subscription. Upgrade to accept ownership and take over billing.
      </p>
      <p :if={@exceeded_limits} class="mt-1 text-sm font-medium">
        This exceeds your current {@exceeded_limits} limits. Upgrade to accept ownership.
      </p>
      <:actions>
        <.button_link
          method="post"
          href={
            Routes.invitation_path(
              PlausibleWeb.Endpoint,
              :reject_invitation,
              @invitation.transfer_id
            )
          }
          theme="ghost"
          size="sm"
          class="order-2 md:order-1"
          mt?={false}
        >
          Reject
        </.button_link>
        <.button_link
          :if={@can_accept?}
          method="post"
          href={
            Routes.invitation_path(
              PlausibleWeb.Endpoint,
              :accept_invitation,
              @invitation.transfer_id
            )
          }
          theme="secondary"
          size="sm"
          class="order-1 md:order-2"
          mt?={false}
        >
          Accept
        </.button_link>
        <.button_link
          :if={not @can_accept?}
          href={Routes.billing_path(PlausibleWeb.Endpoint, :choose_plan)}
          theme="secondary"
          size="sm"
          class="order-1 md:order-2"
          mt?={false}
        >
          Upgrade
        </.button_link>
      </:actions>
    </.notice>
    """
  end

  def site_invitations(assigns) do
    ~H"""
    <aside :if={not Enum.empty?(@site_invitations)} class="flex flex-col gap-y-4">
      <.notice
        :for={i <- @site_invitations}
        id={"site-invitation-#{i.invitation_id}"}
        title={"Invitation to #{i.site.domain}"}
        theme={:white}
      >
        <:icon>
          <div class="shrink-0 -mt-1 bg-green-100/80 dark:bg-green-900/30 rounded-lg p-1.5">
            <.envelope_icon class="size-4 text-green-600 dark:text-green-400" />
          </div>
        </:icon>
        {i.team_invitation.inviter.name} has invited you to join the {i.site.domain} analytics
        dashboard as a {i.role}.
        <:actions>
          <.button_link
            method="post"
            href={Routes.invitation_path(PlausibleWeb.Endpoint, :reject_invitation, i.invitation_id)}
            theme="ghost"
            size="sm"
            class="order-2 md:order-1"
            mt?={false}
          >
            Reject
          </.button_link>
          <.button_link
            method="post"
            href={Routes.invitation_path(PlausibleWeb.Endpoint, :accept_invitation, i.invitation_id)}
            theme="secondary"
            size="sm"
            class="order-1 md:order-2"
            mt?={false}
          >
            Accept
          </.button_link>
        </:actions>
      </.notice>
    </aside>
    """
  end
end
