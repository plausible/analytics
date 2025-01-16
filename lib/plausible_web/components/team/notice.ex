defmodule PlausibleWeb.Team.Notice do
  use PlausibleWeb, :component

  def team_invitations(assigns) do
    ~H"""
    <aside class="mt-4 mb-4">
      <.notice
        :for={i <- @team_invitations}
        title="You have received team invitation"
        class="shadow-md dark:shadow-none mt-4"
      >
        {i.inviter.name} has invited you to join the "{i.team.name}" as {i.role} member.
        <.link method="post" href={Routes.invitation_path(PlausibleWeb.Endpoint, :accept_invitation, i.invitation_id)} class="whitespace-nowrap font-semibold">
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
