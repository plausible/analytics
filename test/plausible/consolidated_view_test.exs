defmodule Plausible.ConsolidatedViewTest do
  use Plausible

  on_ee do
    use Plausible.DataCase, async: true
    import Ecto.Query
    alias Plausible.ConsolidatedView
    import Plausible.Teams.Test

    describe "enable/1 and enabled?/1" do
      setup [:create_user, :create_team]

      test "creates and persists a new consolidated site instance", %{team: team} do
        new_site(team: team)
        assert {:ok, %Plausible.Site{consolidated: true}} = ConsolidatedView.enable(team)
        assert ConsolidatedView.enabled?(team)
      end

      test "is idempotent", %{team: team} do
        new_site(team: team)
        assert {:ok, s1} = ConsolidatedView.enable(team)
        assert {:ok, s2} = ConsolidatedView.enable(team)

        assert 1 =
                 from(s in Plausible.ConsolidatedView.sites(), where: s.team_id == ^team.id)
                 |> Plausible.Repo.aggregate(:count)

        assert s1.domain == s2.domain
      end

      test "returns {:error, :no_sites} when the team does not have any sites", %{team: team} do
        assert {:error, :no_sites} = ConsolidatedView.enable(team)
        refute ConsolidatedView.enabled?(team)
      end

      @tag :skip
      test "returns {:error, :upgrade_required} when team ineligible for this feature"
    end

    describe "disable/1" do
      setup [:create_user, :create_team, :create_site]

      setup %{team: team} do
        ConsolidatedView.enable(team)
        :ok
      end

      test "deletes an existing consolidated site instance", %{team: team} do
        assert ConsolidatedView.get(team)

        assert :ok = ConsolidatedView.disable(team)

        refute ConsolidatedView.get(team)
      end

      test "is idempotent", %{team: team} do
        assert :ok = ConsolidatedView.disable(team)
        assert :ok = ConsolidatedView.disable(team)

        refute ConsolidatedView.get(team)
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

    describe "get/1" do
      setup [:create_user, :create_team, :create_site]

      test "can get by team", %{team: team} do
        assert is_nil(ConsolidatedView.get(team))
        ConsolidatedView.enable(team)
        assert %Plausible.Site{} = ConsolidatedView.get(team)
      end

      test "can get by team.identifier", %{team: team} do
        assert is_nil(ConsolidatedView.get(team.identifier))
        ConsolidatedView.enable(team)
        assert %Plausible.Site{} = ConsolidatedView.get(team.identifier)
      end
    end

    describe "stats start" do
      setup [:create_user, :create_team]

      test "returns earliest native_stats_start_at from included sites", %{team: team} do
        datetimes = [
          ~N[2024-01-01 12:00:00],
          ~N[2024-01-01 11:00:00],
          ~N[2024-02-01 12:00:00]
        ]

        for dt <- datetimes, do: new_site(team: team, native_stats_start_at: dt)

        {:ok, view} = ConsolidatedView.enable(team)

        min = Enum.min(datetimes)
        assert view.native_stats_start_at == min
        assert view.stats_start_date == NaiveDateTime.to_date(min)
      end
    end
  end
end
