defmodule Plausible.Site.AdminTest do
  use Plausible.DataCase, async: true
  use Bamboo.Test

  setup do
    admin_user = insert(:user)
    conn = %Plug.Conn{assigns: %{current_user: admin_user}}
    action = Plausible.SiteAdmin.list_actions(conn)[:transfer_ownership][:action]

    Application.put_env(:plausible, :super_admin_user_ids, [admin_user.id])

    {:ok,
     %{
       action: action,
       conn: conn
     }}
  end

  describe "bulk transferring site ownership" do
    test "user has to select at least one site", %{conn: conn, action: action} do
      assert action.(conn, [], %{}) == {:error, "Please select at least one site from the list"}
    end

    test "new owner must be an existing user", %{conn: conn, action: action} do
      site = insert(:site)

      assert action.(conn, [site], %{"email" => "random@email.com"}) ==
               {:error, "User could not be found"}
    end

    test "initiates ownership transfer for multiple sites in one action", %{
      conn: conn,
      action: action
    } do
      current_owner = insert(:user)
      new_owner = insert(:user)

      site1 =
        insert(:site, memberships: [build(:site_membership, user: current_owner, role: :owner)])

      site2 =
        insert(:site, memberships: [build(:site_membership, user: current_owner, role: :owner)])

      assert :ok = action.(conn, [site1, site2], %{"email" => new_owner.email})

      assert_email_delivered_with(
        to: [nil: new_owner.email],
        subject: "[Plausible Analytics] Request to transfer ownership of #{site1.domain}"
      )

      assert Repo.exists?(
               from i in Plausible.Auth.Invitation,
                 where:
                   i.site_id == ^site1.id and i.email == ^new_owner.email and i.role == :owner
             )

      assert_invitation_exists(site1, new_owner.email, :owner)

      assert_email_delivered_with(
        to: [nil: new_owner.email],
        subject: "[Plausible Analytics] Request to transfer ownership of #{site2.domain}"
      )

      assert_invitation_exists(site2, new_owner.email, :owner)
    end
  end

  defp assert_invitation_exists(site, email, role) do
    assert Repo.exists?(
             from i in Plausible.Auth.Invitation,
               where: i.site_id == ^site.id and i.email == ^email and i.role == ^role
           )
  end
end
