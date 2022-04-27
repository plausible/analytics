defmodule Plausible.Factory do
  use ExMachina.Ecto, repo: Plausible.Repo

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
    %Plausible.Site.SpikeNotification{
      threshold: 10
    }
  end

  def site_factory do
    domain = sequence(:domain, &"example-#{&1}.com")

    %Plausible.Site{
      domain: domain,
      timezone: "UTC"
    }
  end

  def site_membership_factory do
    %Plausible.Site.Membership{}
  end

  def ch_session_factory do
    hostname = sequence(:domain, &"example-#{&1}.com")

    %Plausible.ClickhouseSession{
      sign: 1,
      session_id: SipHash.hash!(hash_key(), UUID.uuid4()),
      user_id: SipHash.hash!(hash_key(), UUID.uuid4()),
      hostname: hostname,
      domain: hostname,
      referrer: "",
      referrer_source: "",
      utm_medium: "",
      utm_source: "",
      utm_campaign: "",
      utm_content: "",
      utm_term: "",
      entry_page: "/",
      pageviews: 1,
      events: 1,
      duration: 0,
      start: Timex.now(),
      timestamp: Timex.now(),
      is_bounce: false,
      browser: "",
      browser_version: "",
      country_code: "",
      screen_size: "",
      operating_system: "",
      operating_system_version: ""
    }
  end

  def pageview_factory do
    struct!(
      event_factory(),
      %{
        name: "pageview"
      }
    )
  end

  def event_factory do
    hostname = sequence(:domain, &"example-#{&1}.com")

    %Plausible.ClickhouseEvent{
      hostname: hostname,
      domain: hostname,
      pathname: "/",
      timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      user_id: SipHash.hash!(hash_key(), UUID.uuid4()),
      session_id: SipHash.hash!(hash_key(), UUID.uuid4()),
      referrer: "",
      referrer_source: "",
      utm_medium: "",
      utm_source: "",
      utm_campaign: "",
      utm_content: "",
      utm_term: "",
      browser: "",
      browser_version: "",
      country_code: "",
      screen_size: "",
      operating_system: "",
      operating_system_version: "",
      "meta.key": [],
      "meta.value": []
    }
  end

  def goal_factory do
    %Plausible.Goal{}
  end

  def subscription_factory do
    %Plausible.Billing.Subscription{
      paddle_subscription_id: sequence(:paddle_subscription_id, &"subscription-#{&1}"),
      paddle_plan_id: sequence(:paddle_plan_id, &"plan-#{&1}"),
      cancel_url: "cancel.com",
      update_url: "cancel.com",
      status: "active",
      next_bill_amount: "6.00",
      next_bill_date: Timex.today(),
      last_bill_date: Timex.today(),
      currency_code: "USD"
    }
  end

  def enterprise_plan_factory do
    %Plausible.Billing.EnterprisePlan{
      paddle_plan_id: sequence(:paddle_plan_id, &"plan-#{&1}"),
      billing_interval: :monthly,
      monthly_pageview_limit: 1_000_000,
      hourly_api_request_limit: 3000,
      site_limit: 100
    }
  end

  def google_auth_factory do
    %Plausible.Site.GoogleAuth{
      email: sequence(:google_auth_email, &"email-#{&1}@email.com"),
      refresh_token: "123",
      access_token: "123",
      expires: Timex.now() |> Timex.shift(days: 1)
    }
  end

  def custom_domain_factory do
    %Plausible.Site.CustomDomain{
      domain: sequence(:custom_domain, &"domain-#{&1}.com")
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

  defp hash_key() do
    Keyword.fetch!(
      Application.get_env(:plausible, PlausibleWeb.Endpoint),
      :secret_key_base
    )
    |> binary_part(0, 16)
  end
end
