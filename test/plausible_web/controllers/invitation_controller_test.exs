defmodule PlausibleWeb.Site.InvitationControllerTest do
  use PlausibleWeb.ConnCase
  use Plausible.Repo
  use Bamboo.Test
  import Plausible.TestUtils

  setup [:create_user, :log_in]

  describe "POST /sites/invitations/:invitation_id/accept" do
    test "converts the invitation into a membership", %{conn: conn, user: user} do
      site = insert(:site)

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: build(:user),
          email: user.email,
          role: :admin
        )

      post(conn, "/sites/invitations/#{invitation.invitation_id}/accept")

      refute Repo.exists?(from(i in Plausible.Auth.Invitation, where: i.email == ^user.email))

      membership = Repo.get_by(Plausible.Site.Membership, user_id: user.id, site_id: site.id)
      assert membership.role == :admin
    end

    test "notifies the original inviter", %{conn: conn, user: user} do
      inviter = insert(:user)
      site = insert(:site)

      invitation =
        insert(:invitation, site_id: site.id, inviter: inviter, email: user.email, role: :admin)

      post(conn, "/sites/invitations/#{invitation.invitation_id}/accept")

      assert_email_delivered_with(
        to: [nil: inviter.email],
        subject: "[Plausible Analytics] #{user.email} accepted your invitation to #{site.domain}"
      )
    end

    test "ownership transfer - notifies the original inviter with a different email", %{
      conn: conn,
      user: user
    } do
      inviter = insert(:user)
      site = insert(:site)

      invitation =
        insert(:invitation, site_id: site.id, inviter: inviter, email: user.email, role: :owner)

      post(conn, "/sites/invitations/#{invitation.invitation_id}/accept")

      assert_email_delivered_with(
        to: [nil: inviter.email],
        subject:
          "[Plausible Analytics] #{user.email} accepted the ownership transfer of #{site.domain}"
      )
    end

    test "ownership transfer - downgrades previous owner to admin", %{conn: conn, user: user} do
      old_owner = insert(:user)
      site = insert(:site, members: [old_owner])

      invitation =
        insert(:invitation, site_id: site.id, inviter: old_owner, email: user.email, role: :owner)

      post(conn, "/sites/invitations/#{invitation.invitation_id}/accept")

      refute Repo.exists?(from(i in Plausible.Auth.Invitation, where: i.email == ^user.email))

      old_owner_membership =
        Repo.get_by(Plausible.Site.Membership, user_id: old_owner.id, site_id: site.id)

      assert old_owner_membership.role == :admin

      new_owner_membership =
        Repo.get_by(Plausible.Site.Membership, user_id: user.id, site_id: site.id)

      assert new_owner_membership.role == :owner
    end

    test "ownership transfer - will lock the site if new owner does not have an active subscription or trial",
         %{
           conn: conn,
           user: user
         } do
      Repo.update_all(from(u in Plausible.Auth.User, where: u.id == ^user.id),
        set: [trial_expiry_date: Timex.today() |> Timex.shift(days: -1)]
      )

      inviter = insert(:user)
      site = insert(:site, locked: false)

      invitation =
        insert(:invitation, site_id: site.id, inviter: inviter, email: user.email, role: :owner)

      post(conn, "/sites/invitations/#{invitation.invitation_id}/accept")

      assert Repo.reload!(site).locked
    end

    test "ownership transfer - will end the trial of the new owner immediately", %{
      conn: conn,
      user: user
    } do
      Repo.update_all(from(u in Plausible.Auth.User, where: u.id == ^user.id),
        set: [trial_expiry_date: Timex.today() |> Timex.shift(days: 7)]
      )

      inviter = insert(:user)
      site = insert(:site, locked: false)

      invitation =
        insert(:invitation, site_id: site.id, inviter: inviter, email: user.email, role: :owner)

      post(conn, "/sites/invitations/#{invitation.invitation_id}/accept")

      assert Timex.before?(Repo.reload!(user).trial_expiry_date, Timex.today())
      assert Repo.reload!(site).locked
    end

    test "ownership transfer - if new owner does not have a trial - will set trial_expiry_date to yesterday",
         %{
           conn: conn,
           user: user
         } do
      Repo.update_all(from(u in Plausible.Auth.User, where: u.id == ^user.id),
        set: [trial_expiry_date: nil]
      )

      inviter = insert(:user)
      site = insert(:site, locked: false)

      invitation =
        insert(:invitation, site_id: site.id, inviter: inviter, email: user.email, role: :owner)

      post(conn, "/sites/invitations/#{invitation.invitation_id}/accept")

      assert Timex.before?(Repo.reload!(user).trial_expiry_date, Timex.today())
      assert Repo.reload!(site).locked
    end
  end

  describe "POST /sites/invitations/:invitation_id/reject" do
    test "deletes the invitation", %{conn: conn, user: user} do
      site = insert(:site)

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: build(:user),
          email: user.email,
          role: :admin
        )

      post(conn, "/sites/invitations/#{invitation.invitation_id}/reject")

      refute Repo.exists?(from(i in Plausible.Auth.Invitation, where: i.email == ^user.email))
    end

    test "notifies the original inviter", %{conn: conn, user: user} do
      inviter = insert(:user)
      site = insert(:site)

      invitation =
        insert(:invitation, site_id: site.id, inviter: inviter, email: user.email, role: :admin)

      post(conn, "/sites/invitations/#{invitation.invitation_id}/reject")

      assert_email_delivered_with(
        to: [nil: inviter.email],
        subject: "[Plausible Analytics] #{user.email} rejected your invitation to #{site.domain}"
      )
    end
  end

  describe "DELETE /sites/invitations/:invitation_id" do
    test "removes the invitation", %{conn: conn} do
      site = insert(:site)

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: build(:user),
          email: "jane@example.com",
          role: :admin
        )

      delete(conn, "/sites/invitations/#{invitation.invitation_id}")

      refute Repo.exists?(
               from i in Plausible.Auth.Invitation, where: i.email == "jane@example.com"
             )
    end
  end
end
