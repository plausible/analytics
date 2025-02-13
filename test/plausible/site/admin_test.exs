defmodule Plausible.Site.AdminTest do
  use Plausible
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test
  use Bamboo.Test

  @subject_prefix if ee?(), do: "[Plausible Analytics] ", else: "[Plausible CE] "

  setup do
    admin_user = insert(:user)

    conn =
      %Plug.Conn{assigns: %{current_user: admin_user}}
      |> Plug.Conn.fetch_query_params()

    transfer_action = Plausible.SiteAdmin.list_actions(conn)[:transfer_ownership][:action]

    transfer_direct_action =
      Plausible.SiteAdmin.list_actions(conn)[:transfer_ownership_direct][:action]

    {:ok,
     %{
       transfer_action: transfer_action,
       transfer_direct_action: transfer_direct_action,
       conn: conn
     }}
  end

  describe "bulk transferring site ownership" do
    test "user has to select at least one site", %{conn: conn, transfer_action: action} do
      assert action.(conn, [], %{}) == {:error, "Please select at least one site from the list"}
    end

    test "new owner must be an existing user", %{conn: conn, transfer_action: action} do
      site = insert(:site)

      assert action.(conn, [site], %{"email" => "random@email.com"}) ==
               {:error, "User could not be found"}
    end

    test "new owner can't be the same as old owner", %{conn: conn, transfer_action: action} do
      current_owner = new_user()
      site = new_site(owner: current_owner)

      assert {:error, "User is already an owner of one of the sites"} =
               action.(conn, [site], %{"email" => current_owner.email})
    end

    test "initiates ownership transfer for multiple sites in one action", %{
      conn: conn,
      transfer_action: action
    } do
      current_owner = new_user()
      new_owner = new_user()
      site1 = new_site(owner: current_owner)
      site2 = new_site(owner: current_owner)

      assert :ok = action.(conn, [site1, site2], %{"email" => new_owner.email})

      assert_email_delivered_with(
        to: [nil: new_owner.email],
        subject: @subject_prefix <> "Request to transfer ownership of #{site1.domain}"
      )

      assert_email_delivered_with(
        to: [nil: new_owner.email],
        subject: @subject_prefix <> "Request to transfer ownership of #{site2.domain}"
      )
    end
  end

  describe "bulk transferring site ownership directly" do
    test "user has to select at least one site", %{conn: conn, transfer_direct_action: action} do
      assert action.(conn, [], %{}) == {:error, "Please select at least one site from the list"}
    end

    test "new owner must be an existing user", %{conn: conn, transfer_direct_action: action} do
      site = new_site()

      assert action.(conn, [site], %{"email" => "random@email.com"}) ==
               {:error, "User could not be found"}
    end

    test "new owner can't be the same as old owner", %{conn: conn, transfer_direct_action: action} do
      current_owner = new_user()
      site = new_site(owner: current_owner)

      assert {:error, "User is already an owner of one of the sites"} =
               action.(conn, [site], %{"email" => current_owner.email})
    end

    test "the provided team identifier must be valid UUID format", %{
      conn: conn,
      transfer_direct_action: action
    } do
      today = Date.utc_today()
      current_owner = new_user()
      site = new_site(owner: current_owner)

      new_owner =
        new_user()
        |> subscribe_to_growth_plan(last_bill_date: Date.shift(today, day: -5))

      assert {:error, "The provided team identifier is invalid"} =
               action.(conn, [site], %{"email" => new_owner.email, "team_id" => "invalid"})
    end

    test "new owner must be owner on a single team if no team identifier provided", %{
      conn: conn,
      transfer_direct_action: action
    } do
      today = Date.utc_today()
      current_owner = new_user()
      site = new_site(owner: current_owner)

      new_owner =
        new_user()
        |> subscribe_to_growth_plan(last_bill_date: Date.shift(today, day: -5))

      another_site = new_site()
      add_member(another_site.team, user: new_owner, role: :owner)

      assert {:error, "The new owner owns more than one team"} =
               action.(conn, [site], %{"email" => new_owner.email})
    end

    test "new owner must be permitted to add sites in the selected team", %{
      conn: conn,
      transfer_direct_action: action
    } do
      today = Date.utc_today()
      current_owner = new_user()
      site = new_site(owner: current_owner)

      new_owner =
        new_user()
        |> subscribe_to_growth_plan(last_bill_date: Date.shift(today, day: -5))

      another_site = new_site()
      new_team = another_site.team
      add_member(new_team, user: new_owner, role: :viewer)

      assert {:error, "The new owner can't add sites in the selected team"} =
               action.(conn, [site], %{
                 "email" => new_owner.email,
                 "team_id" => new_team.identifier
               })
    end

    @tag :ee_only
    test "new owner's plan must accommodate the transferred site", %{
      conn: conn,
      transfer_direct_action: action
    } do
      today = Date.utc_today()
      current_owner = new_user()

      new_owner =
        new_user()
        |> subscribe_to_growth_plan(last_bill_date: Date.shift(today, day: -5))

      # fills the site limit quota
      for _ <- 1..10, do: new_site(owner: new_owner)

      site = new_site(owner: current_owner)

      assert {:error, "Plan limits exceeded" <> _} =
               action.(conn, [site], %{"email" => new_owner.email})
    end

    test "executes ownership transfer for multiple sites in one action", %{
      conn: conn,
      transfer_direct_action: action
    } do
      today = Date.utc_today()
      current_owner = new_user()

      new_owner =
        new_user()
        |> subscribe_to_growth_plan(last_bill_date: Date.shift(today, day: -5))

      site1 = new_site(owner: current_owner)
      site2 = new_site(owner: current_owner)

      assert :ok = action.(conn, [site1, site2], %{"email" => new_owner.email})
    end

    test "executes ownership transfer for multiple sites in one action for provided team", %{
      conn: conn,
      transfer_direct_action: action
    } do
      today = Date.utc_today()
      current_owner = new_user()

      new_owner = new_user()

      another_owner =
        new_user()
        |> subscribe_to_growth_plan(last_bill_date: Date.shift(today, day: -5))

      another_site = new_site(owner: another_owner)
      another_team = another_site.team
      add_member(another_team, user: new_owner, role: :admin)

      site1 = new_site(owner: current_owner)
      site2 = new_site(owner: current_owner)

      assert :ok =
               action.(conn, [site1, site2], %{
                 "email" => new_owner.email,
                 "team_id" => another_team.identifier
               })
    end
  end
end
