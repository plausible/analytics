defmodule Plausible.ConsolidatedViewTest do
  use Plausible.DataCase, async: true
  import Ecto.Query
  alias Plausible.ConsolidatedView

  describe "enable/1" do
    setup [:create_user, :create_team]

    test "creates and persists a new consolidated site instance", %{team: team} do
      assert {:ok, %Plausible.Site{consolidated: true}} = ConsolidatedView.enable(team)
      assert Plausible.Repo.get_by(Plausible.Site, domain: ConsolidatedView.cv_domain(team))
    end

    test "is idempotent", %{team: team} do
      assert {:ok, s1} = ConsolidatedView.enable(team)
      assert {:ok, s2} = ConsolidatedView.enable(team)

      assert 1 =
               from(s in Plausible.Site, where: s.team_id == ^team.id)
               |> Plausible.Repo.aggregate(:count)

      assert s1.domain == s2.domain
    end
  end

  describe "disable/1" do
    setup [:create_user, :create_team]

    setup %{team: team} do
      ConsolidatedView.enable(team)
      :ok
    end

    test "deletes an existing consolidated site instance", %{team: team} do
      assert Plausible.Repo.get_by(Plausible.Site, domain: ConsolidatedView.cv_domain(team))

      assert :ok = ConsolidatedView.disable(team)

      refute Plausible.Repo.get_by(Plausible.Site, domain: ConsolidatedView.cv_domain(team))
    end

    test "is idempotent", %{team: team} do
      assert :ok = ConsolidatedView.disable(team)
      assert :ok = ConsolidatedView.disable(team)

      refute Plausible.Repo.get_by(Plausible.Site, domain: ConsolidatedView.cv_domain(team))
    end
  end
end
