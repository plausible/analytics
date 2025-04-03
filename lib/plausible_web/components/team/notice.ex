defmodule PlausibleWeb.Team.Notice do
  @moduledoc """
  Components with teams related notices.
  """
  use PlausibleWeb, :component

  def owner_cta_banner(assigns) do
    ~H"""
    <aside class="mt-4 mb-4">
      <.notice
        title="A Better Way of Inviting People to Your Team"
        class="shadow-md dark:shadow-none mt-4"
      >
        <p>
          You can now create a team and assign different roles to team members, such as admin,
          editor, viewer or billing. Team members will gain access to all your sites. <a href={
            Routes.team_setup_path(PlausibleWeb.Endpoint, :setup)
          }>Create your team here</a>.
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
          It is now possible to create a team and assign different roles to team members, such as
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
      <.notice theme={:gray} class="rounded border border-gray-300 text-sm mt-4">
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
    <aside :if={not Enum.empty?(@team_invitations)} class="mt-4 mb-4">
      <.notice
        :for={i <- @team_invitations}
        id={"invitation-#{i.invitation_id}"}
        title="You have received team invitation"
        class="shadow-md dark:shadow-none mt-4"
      >
        {i.inviter.name} has invited you to join the "{i.team.name}" as {i.role} member.
        <.link
          method="post"
          href={Routes.invitation_path(PlausibleWeb.Endpoint, :accept_invitation, i.invitation_id)}
          class="whitespace-nowrap font-semibold"
        >
          Accept
        </.link>
        or
        <.link
          method="post"
          href={Routes.invitation_path(PlausibleWeb.Endpoint, :reject_invitation, i.invitation_id)}
          phx-value-invitation-id={i.invitation_id}
          class="whitespace-nowrap font-semibold"
        >
          Reject
        </.link>
      </.notice>
    </aside>
    """
  end
end
