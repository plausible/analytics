defmodule Plausible.PlainCustomerCardsTest do
  use Plausible.DataCase, async: true

  @moduletag :ee_only

  on_ee do
    alias Plausible.PlainCustomerCards

    describe "build_cards/2" do
      test "returns not found card when user does not exist" do
        [card] = PlainCustomerCards.build_cards("notfound@example.com", ["customer-details"])

        assert card.key == "customer-details"

        texts = text_components(card)
        assert "Customer not found" in texts
      end

      test "returns not found card for nil email" do
        [card] = PlainCustomerCards.build_cards(nil, ["customer-details"])

        texts = text_components(card)
        assert "Customer not found" in texts
      end

      test "returns card with status, plan and sites for a known user" do
        user = insert(:user, email: "plain.test@example.com")

        [card] = PlainCustomerCards.build_cards(user.email, ["customer-details"])

        assert card.key == "customer-details"
        assert card.timeToLiveSeconds == 60

        row_labels = row_main_labels(card)
        assert "Status" in row_labels
        assert "Plan" in row_labels
        assert "Sites" in row_labels
      end

      test "includes notes when present" do
        user = insert(:user, email: "plain.notes@example.com", notes: "VIP customer")

        [card] = PlainCustomerCards.build_cards(user.email, ["customer-details"])

        assert "VIP customer" in text_components(card)
      end

      test "includes View in CRM link button" do
        user = insert(:user, email: "plain.link@example.com")

        [card] = PlainCustomerCards.build_cards(user.email, ["customer-details"])

        assert "View in CRM" in link_button_labels(card)
      end

      test "returns one card per requested key" do
        user = insert(:user, email: "plain.keys@example.com")

        cards = PlainCustomerCards.build_cards(user.email, ["customer-details", "other-key"])

        assert length(cards) == 2
      end

      test "returns multiple teams card for user in multiple teams" do
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

        [card] = PlainCustomerCards.build_cards(user.email, ["customer-details"])

        assert Enum.any?(text_components(card), &String.contains?(&1, "Multiple teams"))
        assert "View user in CRM" in link_button_labels(card)
      end
    end

    defp text_components(card) do
      Enum.flat_map(card.components, fn
        %{componentText: %{text: t}} -> [t]
        _ -> []
      end)
    end

    defp row_main_labels(card) do
      Enum.flat_map(card.components, fn
        %{componentRow: %{rowMainContent: content}} ->
          Enum.map(content, fn %{componentText: %{text: t}} -> t end)

        _ ->
          []
      end)
    end

    defp link_button_labels(card) do
      Enum.flat_map(card.components, fn
        %{componentLinkButton: %{linkButtonLabel: label}} -> [label]
        _ -> []
      end)
    end
  end
end
