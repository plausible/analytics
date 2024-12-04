defmodule Plausible.Billing.Quota.Usage do
  @moduledoc false

  use Plausible
  import Ecto.Query
  alias Plausible.Site

  def query_team_member_emails(site_ids) do
    memberships_q =
      from sm in Site.Membership,
        where: sm.site_id in ^site_ids,
        inner_join: u in assoc(sm, :user),
        select: %{email: u.email}

    invitations_q =
      from i in Plausible.Auth.Invitation,
        where: i.site_id in ^site_ids and i.role != :owner,
        select: %{email: i.email}

    union(memberships_q, ^invitations_q)
  end
end
