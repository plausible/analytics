defmodule Plausible.Workers.ScoreTrialProspectsTest do
  use Plausible.DataCase
  @moduletag :ee_only

  on_ee do
    use Oban.Testing, repo: Plausible.Repo

    alias Plausible.Workers.ScoreTrialProspects
    alias Plausible.CustomerSupport.{TrialProspect, TrialProspects}

    describe "TrialProspects scoring (pure)" do
      # No feature/site/member gate (`[], 1, 0`) keeps kind :starter so these
      # assertions isolate the pageview ladder in `score`.
      test "score maps the monthly estimate to the smallest pageview rung >= estimate" do
        assert %{pageview_limit: 10_000, over_top_tier: false} =
                 TrialProspects.score(6_000, [], 1, 0)

        assert %{pageview_limit: 100_000, over_top_tier: false} =
                 TrialProspects.score(80_000, [], 1, 0)

        assert %{pageview_limit: 500_000, over_top_tier: false} =
                 TrialProspects.score(350_000, [], 1, 0)

        assert %{pageview_limit: 10_000_000, over_top_tier: false} =
                 TrialProspects.score(10_000_000, [], 1, 0)

        assert %{pageview_limit: nil, over_top_tier: true} =
                 TrialProspects.score(14_000_000, [], 1, 0)
      end

      test "score escalates plan kind to the highest tier a used feature forces" do
        assert %{kind: :starter, forced_by: []} = TrialProspects.score(6_000, [], 1, 0)

        assert %{kind: :starter, forced_by: []} =
                 TrialProspects.score(6_000, [Plausible.Billing.Feature.Goals], 1, 0)

        assert %{kind: :growth, forced_by: ["shared_links"]} =
                 TrialProspects.score(6_000, [Plausible.Billing.Feature.SharedLinks], 1, 0)

        assert %{kind: :growth, forced_by: ["site_annotations"]} =
                 TrialProspects.score(6_000, [Plausible.Billing.Feature.SiteAnnotations], 1, 0)

        # a growth feature never downgrades a business tier forced elsewhere
        assert %{kind: :business, forced_by: ["funnels"]} =
                 TrialProspects.score(
                   6_000,
                   [
                     Plausible.Billing.Feature.SiteAnnotations,
                     Plausible.Billing.Feature.Funnels
                   ],
                   1,
                   0
                 )

        assert %{kind: :business, forced_by: ["funnels", "props"]} =
                 TrialProspects.score(
                   6_000,
                   [
                     Plausible.Billing.Feature.Funnels,
                     Plausible.Billing.Feature.Props,
                     Plausible.Billing.Feature.SharedLinks
                   ],
                   1,
                   0
                 )
      end

      test "score escalates plan kind on site count (plans_v5 site_limit)" do
        # starter allows 1 site, growth 3, business 10
        assert %{kind: :starter, forced_by: []} = TrialProspects.score(6_000, [], 1, 0)
        assert %{kind: :growth, forced_by: ["site_limit"]} = TrialProspects.score(6_000, [], 2, 0)
        assert %{kind: :growth, forced_by: ["site_limit"]} = TrialProspects.score(6_000, [], 3, 0)

        assert %{kind: :business, forced_by: ["site_limit"]} =
                 TrialProspects.score(6_000, [], 4, 0)

        assert %{kind: :business, forced_by: ["site_limit"]} =
                 TrialProspects.score(6_000, [], 25, 0)
      end

      test "score escalates plan kind on team member count (plans_v5 team_member_limit)" do
        # starter is solo (0 extra members), growth allows 3, business 10
        assert %{kind: :starter, forced_by: []} = TrialProspects.score(6_000, [], 1, 0)

        assert %{kind: :growth, forced_by: ["team_member_limit"]} =
                 TrialProspects.score(6_000, [], 1, 1)

        assert %{kind: :growth, forced_by: ["team_member_limit"]} =
                 TrialProspects.score(6_000, [], 1, 3)

        assert %{kind: :business, forced_by: ["team_member_limit"]} =
                 TrialProspects.score(6_000, [], 1, 4)
      end

      test "score takes the highest tier across features, sites and members" do
        # a growth feature but a business-sized site count -> business; no business
        # feature forced it, so only the site limit is listed
        assert %{kind: :business, forced_by: ["site_limit"]} =
                 TrialProspects.score(6_000, [Plausible.Billing.Feature.SharedLinks], 5, 0)

        # a business feature with tiny site/member counts still wins on features
        assert %{kind: :business, forced_by: ["funnels"]} =
                 TrialProspects.score(6_000, [Plausible.Billing.Feature.Funnels], 1, 0)

        # both a business feature and the site count force business -> both listed
        assert %{kind: :business, forced_by: ["funnels", "site_limit"]} =
                 TrialProspects.score(6_000, [Plausible.Billing.Feature.Funnels], 4, 0)
      end

      test "score prices the estimate against the plan kind, nil over the top tier" do
        # starter @ 10k rung
        assert %{kind: :starter, estimated_mrr: 9} = TrialProspects.score(6_000, [], 1, 0)

        # growth @ 2M rung (estimate lands between the 1M and 2M rungs)
        assert %{kind: :growth, estimated_mrr: 134} =
                 TrialProspects.score(1_500_000, [Plausible.Billing.Feature.SharedLinks], 1, 0)

        # business @ 10M rung
        assert %{kind: :business, estimated_mrr: 339} =
                 TrialProspects.score(8_000_000, [Plausible.Billing.Feature.Funnels], 1, 0)

        # over the top tier -> no price
        assert %{over_top_tier: true, estimated_mrr: nil} =
                 TrialProspects.score(14_000_000, [Plausible.Billing.Feature.Funnels], 1, 0)
      end

      test "score combines feature usage and estimate" do
        assert %{
                 kind: :business,
                 forced_by: ["funnels"],
                 pageview_limit: 500_000,
                 over_top_tier: false,
                 estimated_mrr: 99
               } = TrialProspects.score(350_000, [Plausible.Billing.Feature.Funnels], 1, 0)
      end
    end

    describe "worker" do
      test "scores a trial team with traffic" do
        user = new_user(trial_expiry_date: Date.add(Date.utc_today(), 7))
        site = new_site(owner: user)
        populate_stats(site, pageviews_on(Date.add(Date.utc_today(), -10), 10))

        assert :ok = perform_job(ScoreTrialProspects, %{})

        prospect = Repo.get_by!(TrialProspect, team_id: team_of(user).id)
        assert prospect.observed_days == 10
        assert prospect.estimated_monthly == 30
        assert prospect.first_data_day == Date.add(Date.utc_today(), -10)
        assert prospect.kind == :starter
        assert prospect.forced_by == []
        assert prospect.pageview_limit == 10_000
        assert prospect.over_top_tier == false
        assert prospect.estimated_mrr == 9
      end

      test "estimate spans from earliest traffic day across multiple days" do
        user = new_user(trial_expiry_date: Date.add(Date.utc_today(), 7))
        site = new_site(owner: user)
        # earliest traffic 10 days ago, more 3 days ago -> observed over 10 days
        populate_stats(
          site,
          pageviews_on(Date.add(Date.utc_today(), -10), 4) ++
            pageviews_on(Date.add(Date.utc_today(), -3), 6)
        )

        assert :ok = perform_job(ScoreTrialProspects, %{})

        prospect = Repo.get_by!(TrialProspect, team_id: team_of(user).id)
        assert prospect.first_data_day == Date.add(Date.utc_today(), -10)
        assert prospect.observed_days == 10
        # 10 events / 10 days * 30.4
        assert prospect.estimated_monthly == 30
      end

      test "premium feature usage forces a higher plan kind and price" do
        user = new_user(trial_expiry_date: Date.add(Date.utc_today(), 7))
        site = new_site(owner: user, allowed_event_props: ["author"])
        populate_stats(site, pageviews_on(Date.add(Date.utc_today(), -10), 10))

        assert :ok = perform_job(ScoreTrialProspects, %{})

        prospect = Repo.get_by!(TrialProspect, team_id: team_of(user).id)
        assert prospect.kind == :business
        assert prospect.forced_by == ["props"]
        assert prospect.estimated_mrr == 19
      end

      test "site annotation usage forces a higher plan kind" do
        user = new_user(trial_expiry_date: Date.add(Date.utc_today(), 7))
        site = new_site(owner: user)
        insert(:annotation, site: site, type: :site)
        populate_stats(site, pageviews_on(Date.add(Date.utc_today(), -10), 10))

        assert :ok = perform_job(ScoreTrialProspects, %{})

        prospect = Repo.get_by!(TrialProspect, team_id: team_of(user).id)
        assert prospect.kind == :growth
        assert prospect.forced_by == ["site_annotations"]
        assert prospect.estimated_mrr == 14
      end

      test "a personal annotation does not force a higher plan kind" do
        user = new_user(trial_expiry_date: Date.add(Date.utc_today(), 7))
        site = new_site(owner: user)
        insert(:annotation, site: site, type: :personal, owner: user)
        populate_stats(site, pageviews_on(Date.add(Date.utc_today(), -10), 10))

        assert :ok = perform_job(ScoreTrialProspects, %{})

        prospect = Repo.get_by!(TrialProspect, team_id: team_of(user).id)
        assert prospect.kind == :starter
        assert prospect.forced_by == []
      end

      test "site count alone forces a higher plan kind" do
        user = new_user(trial_expiry_date: Date.add(Date.utc_today(), 7))
        # 4 owned sites, no premium features -> over growth's 3-site limit -> business
        site = new_site(owner: user)
        for _ <- 1..3, do: new_site(owner: user)
        populate_stats(site, pageviews_on(Date.add(Date.utc_today(), -10), 10))

        assert :ok = perform_job(ScoreTrialProspects, %{})

        prospect = Repo.get_by!(TrialProspect, team_id: team_of(user).id)
        assert prospect.kind == :business
        assert prospect.forced_by == ["site_limit"]
        assert prospect.estimated_mrr == 19
      end

      test "team member count alone forces a higher plan kind" do
        user = new_user(trial_expiry_date: Date.add(Date.utc_today(), 7))
        site = new_site(owner: user)
        # one extra member -> over starter's solo (0-member) limit -> growth
        add_member(team_of(user), role: :viewer)
        populate_stats(site, pageviews_on(Date.add(Date.utc_today(), -10), 10))

        assert :ok = perform_job(ScoreTrialProspects, %{})

        prospect = Repo.get_by!(TrialProspect, team_id: team_of(user).id)
        assert prospect.kind == :growth
        assert prospect.forced_by == ["team_member_limit"]
        assert prospect.estimated_mrr == 14
      end

      test "does not score a team with no complete day of traffic" do
        user = new_user(trial_expiry_date: Date.add(Date.utc_today(), 7))
        site = new_site(owner: user)
        # only today (partial, excluded)
        populate_stats(site, pageviews_on(Date.utc_today(), 5))

        assert :ok = perform_job(ScoreTrialProspects, %{})

        assert Repo.get_by(TrialProspect, team_id: team_of(user).id) == nil
      end

      test "does not score teams with a subscription" do
        user = new_user(trial_expiry_date: Date.add(Date.utc_today(), 7))
        site = new_site(owner: user)
        subscribe_to_growth_plan(user)
        populate_stats(site, pageviews_on(Date.add(Date.utc_today(), -10), 10))

        assert :ok = perform_job(ScoreTrialProspects, %{})

        assert Repo.get_by(TrialProspect, team_id: team_of(user).id) == nil
      end

      test "leaves rows for teams no longer in the population untouched" do
        # eligible team
        user = new_user(trial_expiry_date: Date.add(Date.utc_today(), 7))
        site = new_site(owner: user)
        populate_stats(site, pageviews_on(Date.add(Date.utc_today(), -10), 10))

        # a trial that expired beyond the window, with a leftover row that is no
        # longer part of the population -> must be preserved, not deleted
        old_user = new_user(trial_expiry_date: Date.add(Date.utc_today(), -90))
        old_team = team_of(old_user)

        %TrialProspect{}
        |> Ecto.Changeset.change(
          team_id: old_team.id,
          estimated_monthly: 100,
          observed_days: 5,
          first_data_day: Date.utc_today(),
          kind: :starter,
          computed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )
        |> Repo.insert!()

        assert :ok = perform_job(ScoreTrialProspects, %{})

        assert Repo.get_by(TrialProspect, team_id: old_team.id)
        assert Repo.get_by(TrialProspect, team_id: team_of(user).id)
      end

      test "upserts on re-run rather than duplicating" do
        user = new_user(trial_expiry_date: Date.add(Date.utc_today(), 7))
        site = new_site(owner: user)
        populate_stats(site, pageviews_on(Date.add(Date.utc_today(), -10), 10))

        assert :ok = perform_job(ScoreTrialProspects, %{})
        assert :ok = perform_job(ScoreTrialProspects, %{})

        assert [_only_one] =
                 Repo.all(from p in TrialProspect, where: p.team_id == ^team_of(user).id)
      end

      test "scores a recently expired trial that still has in-window traffic" do
        # trial ended 2 days ago -> within the 60-day population window (spec §2)
        user = new_user(trial_expiry_date: Date.add(Date.utc_today(), -2))
        site = new_site(owner: user)
        populate_stats(site, pageviews_on(Date.add(Date.utc_today(), -5), 10))

        assert :ok = perform_job(ScoreTrialProspects, %{})

        prospect = Repo.get_by!(TrialProspect, team_id: team_of(user).id)
        assert prospect.observed_days == 5
        # 10 events / 5 days * 30 -> 60
        assert prospect.estimated_monthly == 60
        assert prospect.kind == :starter
        assert prospect.estimated_mrr == 9
      end

      test "counts pageviews and custom events but excludes engagement" do
        user = new_user(trial_expiry_date: Date.add(Date.utc_today(), 7))
        site = new_site(owner: user)
        # single complete day -> observed_days = 1
        t = NaiveDateTime.new!(Date.add(Date.utc_today(), -1), ~T[12:00:00])

        # engagement events need a preceding pageview (shared user_id) for a session
        events =
          [
            build(:pageview, user_id: 1, timestamp: t),
            build(:pageview, user_id: 2, timestamp: t),
            build(:pageview, user_id: 3, timestamp: t),
            build(:pageview, user_id: 4, timestamp: t),
            build(:engagement, user_id: 1, timestamp: t, engagement_time: 5000),
            build(:engagement, user_id: 2, timestamp: t, engagement_time: 5000)
          ] ++ for(_ <- 1..6, do: build(:event, name: "Signup", user_id: 5, timestamp: t))

        populate_stats(site, events)

        assert :ok = perform_job(ScoreTrialProspects, %{})

        prospect = Repo.get_by!(TrialProspect, team_id: team_of(user).id)
        assert prospect.observed_days == 1
        # billable total = 4 pageviews + 6 custom events; the engagements are
        # excluded. 10 events * 30 -> 300 (would be higher if engagement counted).
        assert prospect.estimated_monthly == 300
      end

      test "ignores traffic older than the sampling window and caps observed_days at 30" do
        user = new_user(trial_expiry_date: Date.add(Date.utc_today(), 7))
        site = new_site(owner: user)

        populate_stats(
          site,
          # 40 days ago: before the 30-day window -> must be ignored entirely
          # window floor (30 complete days ago): sets first_data_day, observed_days = 30
          pageviews_on(Date.add(Date.utc_today(), -40), 1000) ++
            pageviews_on(Date.add(Date.utc_today(), -30), 1) ++
            pageviews_on(Date.add(Date.utc_today(), -1), 59)
        )

        assert :ok = perform_job(ScoreTrialProspects, %{})

        prospect = Repo.get_by!(TrialProspect, team_id: team_of(user).id)
        # earliest day *within* the window, not the 40-day-old batch
        assert prospect.first_data_day == Date.add(Date.utc_today(), -30)
        # clamped to the window length
        assert prospect.observed_days == 30
        # only the 60 in-window events count (1 + 59); 60 / 30 * 30 -> 60.
        # Had the 40-day-old batch leaked in it would be ~1074.
        assert prospect.estimated_monthly == 60
      end
    end

    defp pageviews_on(date, count) do
      timestamp = NaiveDateTime.new!(date, ~T[12:00:00])
      for _ <- 1..count, do: build(:pageview, timestamp: timestamp)
    end
  end
end
