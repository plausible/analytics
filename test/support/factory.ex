defmodule Plausible.Factory do
  use ExMachina.Ecto, repo: Plausible.Repo
  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing.Subscription

  def team_factory do
    %Plausible.Teams.Team{
      name: "My Team",
      trial_expiry_date: Timex.today() |> Timex.shift(days: 30)
    }
  end

  def team_membership_factory do
    %Plausible.Teams.Membership{
      user: build(:user),
      role: :viewer
    }
  end

  def guest_membership_factory do
    %Plausible.Teams.GuestMembership{
      team_membership: build(:team_membership, role: :guest)
    }
  end

  def team_invitation_factory do
    %Plausible.Teams.Invitation{
      invitation_id: Nanoid.generate(),
      email: sequence(:email, &"email-#{&1}@example.com"),
      role: :admin
    }
  end

  def guest_invitation_factory do
    %Plausible.Teams.GuestInvitation{
      invitation_id: Nanoid.generate(),
      role: :editor,
      team_invitation: build(:team_invitation, role: :guest)
    }
  end

  def site_transfer_factory do
    %Plausible.Teams.SiteTransfer{
      transfer_id: Nanoid.generate(),
      email: sequence(:email, &"email-#{&1}@example.com")
    }
  end

  def user_factory(attrs) do
    pw = Map.get(attrs, :password, "password")

    user = %Plausible.Auth.User{
      name: "Jane Smith",
      email: sequence(:email, &"email-#{&1}@example.com"),
      password_hash: Plausible.Auth.Password.hash(pw),
      trial_expiry_date: Timex.today() |> Timex.shift(days: 30),
      email_verified: true
    }

    merge_attributes(user, attrs)
  end

  def spike_notification_factory do
    %Plausible.Site.TrafficChangeNotification{
      threshold: 10,
      type: :spike
    }
  end

  def drop_notification_factory do
    %Plausible.Site.TrafficChangeNotification{
      threshold: 1,
      type: :drop
    }
  end

  def site_factory(attrs) do
    # The é exercises unicode support in domain names
    domain = sequence(:domain, &"é-#{&1}.example.com")

    defined_memberships? =
      Map.has_key?(attrs, :memberships) ||
        Map.has_key?(attrs, :members) ||
        Map.has_key?(attrs, :owner)

    attrs =
      if defined_memberships?,
        do: attrs,
        else: Map.put_new(attrs, :members, [build(:user)])

    site = %Plausible.Site{
      native_stats_start_at: ~N[2000-01-01 00:00:00],
      domain: domain,
      timezone: "UTC"
    }

    merge_attributes(site, attrs)
  end

  def site_membership_factory do
    %Plausible.Site.Membership{
      user: build(:user),
      role: :viewer
    }
  end

  def site_import_factory do
    today = Date.utc_today()

    %Plausible.Imported.SiteImport{
      site: build(:site),
      imported_by: build(:user),
      start_date: Date.add(today, -200),
      end_date: today,
      source: :universal_analytics,
      status: :completed,
      legacy: false
    }
  end

  def ch_session_factory do
    hostname = sequence(:domain, &"example-#{&1}.com")

    %Plausible.ClickhouseSessionV2{
      sign: 1,
      session_id: SipHash.hash!(hash_key(), Ecto.UUID.generate()),
      user_id: SipHash.hash!(hash_key(), Ecto.UUID.generate()),
      hostname: hostname,
      site_id: Enum.random(1000..10_000),
      entry_page: "/",
      pageviews: 1,
      events: 1,
      start: Timex.now(),
      timestamp: Timex.now(),
      is_bounce: false
    }
  end

  def pageview_factory(attrs) do
    Map.put(event_factory(attrs), :name, "pageview")
  end

  def pageleave_factory(attrs) do
    Map.put(event_factory(attrs), :name, "pageleave")
  end

  def event_factory(attrs) do
    if Map.get(attrs, :acquisition_channel) do
      raise "Acquisition channel cannot be written directly since it's a materialized column."
    end

    hostname = sequence(:domain, &"example-#{&1}.com")

    event = %Plausible.ClickhouseEventV2{
      hostname: hostname,
      site_id: Enum.random(1000..10_000),
      pathname: "/",
      timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      user_id: SipHash.hash!(hash_key(), Ecto.UUID.generate()),
      session_id: SipHash.hash!(hash_key(), Ecto.UUID.generate())
    }

    event
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  def goal_factory(attrs) do
    display_name_provided? = Map.has_key?(attrs, :display_name)

    attrs =
      case {attrs, display_name_provided?} do
        {%{page_path: path}, false} when is_binary(path) ->
          Map.put(attrs, :display_name, "Visit " <> path)

        {%{page_path: path}, false} when is_function(path, 0) ->
          attrs
          |> Map.put(:display_name, "Visit " <> path.())
          |> Map.put(:page_path, path.())

        {%{event_name: event_name}, false} when is_binary(event_name) ->
          Map.put(attrs, :display_name, event_name)

        {%{event_name: event_name}, false} when is_function(event_name, 0) ->
          attrs
          |> Map.put(:display_name, event_name.())
          |> Map.put(:event_name, event_name.())

        _ ->
          attrs
      end

    merge_attributes(%Plausible.Goal{}, attrs)
  end

  def subscription_factory do
    %Plausible.Billing.Subscription{
      paddle_subscription_id: sequence(:paddle_subscription_id, &"subscription-#{&1}"),
      paddle_plan_id: sequence(:paddle_plan_id, &"plan-#{&1}"),
      cancel_url: "cancel.com",
      update_url: "cancel.com",
      status: Subscription.Status.active(),
      next_bill_amount: "6.00",
      next_bill_date: Timex.today(),
      last_bill_date: Timex.today(),
      currency_code: "USD"
    }
  end

  def growth_subscription_factory do
    build(:subscription, paddle_plan_id: "857097")
  end

  def business_subscription_factory do
    build(:subscription, paddle_plan_id: "857087")
  end

  def enterprise_plan_factory do
    %Plausible.Billing.EnterprisePlan{
      paddle_plan_id: sequence(:paddle_plan_id, &"plan-#{&1}"),
      billing_interval: :monthly,
      monthly_pageview_limit: 1_000_000,
      hourly_api_request_limit: 3000,
      site_limit: 100,
      team_member_limit: 10
    }
  end

  def google_auth_factory do
    %Plausible.Site.GoogleAuth{
      email: sequence(:google_auth_email, &"email-#{&1}@example.com"),
      refresh_token: "123",
      access_token: "123",
      expires: Timex.now() |> Timex.shift(days: 1)
    }
  end

  def weekly_report_factory do
    %Plausible.Site.WeeklyReport{}
  end

  def monthly_report_factory do
    %Plausible.Site.MonthlyReport{}
  end

  def shared_link_factory do
    %Plausible.Site.SharedLink{
      name: "Link name",
      slug: Nanoid.generate()
    }
  end

  def invitation_factory do
    %Plausible.Auth.Invitation{
      invitation_id: Nanoid.generate(),
      email: sequence(:email, &"email-#{&1}@example.com"),
      role: :admin
    }
  end

  def api_key_factory do
    key = :crypto.strong_rand_bytes(64) |> Base.url_encode64() |> binary_part(0, 64)

    %Plausible.Auth.ApiKey{
      name: "api-key-name",
      key: key,
      key_hash: Plausible.Auth.ApiKey.do_hash(key),
      key_prefix: binary_part(key, 0, 6)
    }
  end

  def imported_visitors_factory do
    %{
      table: "imported_visitors",
      date: Timex.today(),
      visitors: 1,
      pageviews: 1,
      bounces: 0,
      visits: 1,
      visit_duration: 10
    }
  end

  def imported_sources_factory do
    %{
      table: "imported_sources",
      date: Timex.today(),
      source: "",
      visitors: 1,
      visits: 1,
      bounces: 0,
      visit_duration: 10
    }
  end

  def imported_pages_factory do
    %{
      table: "imported_pages",
      date: Timex.today(),
      page: "",
      visitors: 1,
      pageviews: 1,
      exits: 0,
      time_on_page: 10
    }
  end

  def imported_entry_pages_factory do
    %{
      table: "imported_entry_pages",
      date: Timex.today(),
      entry_page: "",
      visitors: 1,
      entrances: 1,
      bounces: 0,
      visit_duration: 10
    }
  end

  def imported_exit_pages_factory do
    %{
      table: "imported_exit_pages",
      date: Timex.today(),
      exit_page: "",
      visitors: 1,
      exits: 1
    }
  end

  def imported_custom_events_factory do
    %{
      table: "imported_custom_events",
      date: Timex.today(),
      name: "",
      link_url: "",
      visitors: 1,
      events: 1
    }
  end

  def imported_locations_factory do
    %{
      table: "imported_locations",
      date: Timex.today(),
      country: "",
      region: "",
      city: 0,
      visitors: 1,
      visits: 1,
      bounces: 0,
      visit_duration: 10
    }
  end

  def imported_devices_factory do
    %{
      table: "imported_devices",
      date: Timex.today(),
      device: "",
      visitors: 1,
      visits: 1,
      bounces: 0,
      visit_duration: 10
    }
  end

  def imported_browsers_factory do
    %{
      table: "imported_browsers",
      date: Timex.today(),
      browser: "",
      visitors: 1,
      visits: 1,
      bounces: 0,
      visit_duration: 10
    }
  end

  def imported_operating_systems_factory do
    %{
      table: "imported_operating_systems",
      date: Timex.today(),
      operating_system: "",
      visitors: 1,
      visits: 1,
      bounces: 0,
      visit_duration: 10
    }
  end

  def ip_rule_factory do
    %Plausible.Shield.IPRule{
      inet: Plausible.TestUtils.random_ip(),
      description: "Test IP Rule",
      added_by: "Mr Seed <user@plausible.test>"
    }
  end

  def country_rule_factory do
    %Plausible.Shield.CountryRule{
      added_by: "Mr Seed <user@plausible.test>"
    }
  end

  defp hash_key() do
    Keyword.fetch!(
      Application.get_env(:plausible, PlausibleWeb.Endpoint),
      :secret_key_base
    )
    |> binary_part(0, 16)
  end
end
