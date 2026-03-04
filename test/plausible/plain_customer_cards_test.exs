defmodule Plausible.PlainCustomerCardsTest do
  use Plausible.DataCase, async: true

  @moduletag :ee_only

  on_ee do
    alias Plausible.PlainCustomerCards

    describe "get_customer_data/1" do
      test "returns error when user not found" do
        assert {:error, {:user_not_found, "notfound@example.com"}} =
                 PlainCustomerCards.get_customer_data("notfound@example.com")
      end

      test "returns single team details for a user with one team" do
        user = insert(:user, email: "plain.test@example.com")

        {:ok, details} = PlainCustomerCards.get_customer_data(user.email)

        assert details.multiple_teams? == false
        assert details.email == user.email
      end

      test "returns multiple teams details for user in multiple teams" do
        user = new_user(email: "plain.multi@example.com")
        other_user = new_user()
        _site1 = new_site(owner: user)
        _site2 = new_site(owner: other_user)

        team2 = team_of(other_user)

        team2 =
          team2
          |> Plausible.Teams.complete_setup()
          |> Ecto.Changeset.change(name: "Plain Test Team")
          |> Plausible.Repo.update!()

        add_member(team2, user: user, role: :owner)

        {:ok, details} = PlainCustomerCards.get_customer_data(user.email)

        assert details.multiple_teams? == true
        assert length(details.teams) == 2
      end

      test "includes notes when present" do
        user = insert(:user, email: "plain.notes@example.com", notes: "Important customer")

        {:ok, details} = PlainCustomerCards.get_customer_data(user.email)

        assert details.notes == "Important customer"
      end
    end

    describe "build_card/1 for single team" do
      test "builds card with status, plan, sites, and admin link" do
        user = insert(:user, email: "plain.card@example.com")

        {:ok, details} = PlainCustomerCards.get_customer_data(user.email)
        card = PlainCustomerCards.build_card(details)

        assert card.key == "customer-details"
        assert card.timeToLiveSeconds == 60
        assert is_list(card.components)

        labels =
          card.components
          |> Enum.flat_map(fn
            %{componentRow: %{rowMainContent: content}} ->
              Enum.map(content, fn %{componentText: %{text: t}} -> t end)

            _ ->
              []
          end)

        assert "Status" in labels
        assert "Plan" in labels
        assert "Sites" in labels
      end

      test "includes notes as text component when present" do
        user = insert(:user, email: "plain.card2@example.com", notes: "VIP customer")

        {:ok, details} = PlainCustomerCards.get_customer_data(user.email)
        card = PlainCustomerCards.build_card(details)

        texts =
          card.components
          |> Enum.flat_map(fn
            %{componentText: %{text: t}} -> [t]
            _ -> []
          end)

        assert "VIP customer" in texts
      end

      test "includes View in admin link button" do
        user = insert(:user, email: "plain.card3@example.com")

        {:ok, details} = PlainCustomerCards.get_customer_data(user.email)
        card = PlainCustomerCards.build_card(details)

        link_buttons =
          card.components
          |> Enum.flat_map(fn
            %{componentLinkButton: btn} -> [btn]
            _ -> []
          end)

        labels = Enum.map(link_buttons, & &1.linkButtonLabel)
        assert "View in CRM" in labels
      end
    end

    describe "build_card/1 for multiple teams" do
      test "builds card with team list" do
        user = new_user(email: "plain.multi2@example.com")
        other_user = new_user()
        _site1 = new_site(owner: user)
        _site2 = new_site(owner: other_user)

        team2 = team_of(other_user)

        team2 =
          team2
          |> Plausible.Teams.complete_setup()
          |> Ecto.Changeset.change(name: "Plain Multi Team")
          |> Plausible.Repo.update!()

        add_member(team2, user: user, role: :owner)

        {:ok, details} = PlainCustomerCards.get_customer_data(user.email)
        card = PlainCustomerCards.build_card(details)

        assert card.key == "customer-details"

        texts =
          card.components
          |> Enum.flat_map(fn
            %{componentText: %{text: t}} -> [t]
            _ -> []
          end)

        assert Enum.any?(texts, &String.contains?(&1, "Multiple teams"))

        link_buttons =
          card.components
          |> Enum.flat_map(fn
            %{componentLinkButton: btn} -> [btn]
            _ -> []
          end)

        labels = Enum.map(link_buttons, & &1.linkButtonLabel)
        assert "View user in CRM" in labels
      end
    end
  end
end
