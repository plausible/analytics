defmodule Plausible.Teams.Memberships.RemoveGuestTest do
  use Plausible.DataCase, async: true
  use Bamboo.Test

  alias Plausible.Teams

  @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

  describe "remove/3" do
    setup [:create_user, :create_site]

    test "removes a guest and notifies them by e-mail", %{site: site} do
      guest = add_guest(site, role: :viewer)

      assert {:ok, %Teams.GuestMembership{}} = Teams.Memberships.remove(site, guest)

      assert {:error, :not_a_member} = Teams.Memberships.site_role(site, guest)

      assert_email_delivered_with(
        to: [nil: guest.email],
        subject: @subject_prefix <> "Your access to #{site.domain} has been revoked"
      )
    end

    test "doesn't send the e-mail when send_email? is false", %{site: site} do
      guest = add_guest(site, role: :viewer)

      assert {:ok, %Teams.GuestMembership{}} =
               Teams.Memberships.remove(site, guest, send_email?: false)

      assert {:error, :not_a_member} = Teams.Memberships.site_role(site, guest)
      assert_no_emails_delivered()
    end

    test "returns an error when the user isn't a guest of the site", %{site: site, user: owner} do
      assert {:error, :no_guest} = Teams.Memberships.remove(site, owner)
      assert {:ok, {:team_member, :owner}} = Teams.Memberships.site_role(site, owner)
      assert_no_emails_delivered()
    end
  end
end
