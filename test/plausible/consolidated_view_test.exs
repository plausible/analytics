defmodule Plausible.ConsolidatedViewTest do
  use Plausible

  on_ee do
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

      @tag :skip
      test "returns {:error, :upgrade_required} when team ineligible for this feature"
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

    describe "site_ids/1" do
      setup [:create_user, :create_team, :create_site]

      test "returns {:error, :not_found} when no consolidated view exists", %{team: team} do
        assert {:error, :not_found} = ConsolidatedView.site_ids(team)
      end

      test "returns site_ids owned by the team when consolidated view exists", %{
        team: team,
        site: site
      } do
        ConsolidatedView.enable(team)
        assert ConsolidatedView.site_ids(team) == {:ok, [site.id]}
      end
    end
  end
end
