defmodule PlausibleE2E.Fixtures do
  @moduledoc """
  Port of e2e/tests/fixtures.ts. Functions take keyword options where the JS takes an
  object, `page` and `request` among them. A user is `%{name:, email:, password:}`.
  """

  import Playwright.Test.Assertions
  import PlausibleE2E.Utils

  alias Playwright.{APIRequestContext, APIResponse, Expect, Locator, Page}

  @json_headers %{"Content-Type" => "application/json", "Accept" => "application/json"}

  def register(opts) do
    page = Keyword.fetch!(opts, :page)
    request = Keyword.fetch!(opts, :request)
    user = Keyword.fetch!(opts, :user)

    Page.goto!(page, "/register", wait_until: :commit)

    expect_live_view_connected(page)

    Expect.to_be_visible!(Page.get_by_role(page, :button, name: "Start my free trial"))

    Page.get_by_label(page, "Full name") |> Locator.fill!(user.name)
    Page.get_by_label(page, "Email") |> Locator.fill!(user.email)
    Page.get_by_label(page, "Password", exact: true) |> Locator.fill!(user.password)
    Expect.to_be_enabled!(Page.get_by_role(page, :button, name: "Start my free trial"))
    Page.get_by_role(page, :button, name: "Start my free trial") |> Locator.click!()

    Expect.to_be_visible!(Page.get_by_role(page, :heading, name: "Check your email"))

    response = APIRequestContext.get!(request, "/sent-emails-api/emails.json")
    email_data = APIResponse.json!(response)

    emails =
      Enum.filter(email_data, fn e ->
        e["to"] |> hd() |> hd() == user.name and
          String.contains?(e["subject"], "is your Plausible email verification code")
      end)

    assert length(emails) == 1

    [code | _] = emails |> hd() |> Map.fetch!("subject") |> String.split(" ")

    Page.locator(page, "input[name=code]") |> Locator.fill!(code)

    Page.get_by_role(page, :button, name: "Activate") |> Locator.click!()

    Expect.to_be_visible!(Page.get_by_role(page, :button, name: "Add site"))
  end

  def login(opts) do
    page = Keyword.fetch!(opts, :page)
    user = Keyword.fetch!(opts, :user)

    Page.goto!(page, "/login", wait_until: :commit)

    Expect.to_be_visible!(Page.get_by_role(page, :button, name: "Sign in"))

    Page.get_by_label(page, "Email") |> Locator.fill!(user.email)
    Page.get_by_label(page, "Password", exact: true) |> Locator.fill!(user.password)
    Page.get_by_role(page, :button, name: "Sign in") |> Locator.click!()

    Expect.to_be_visible!(Page.get_by_role(page, :button, name: user.name))
  end

  def logout(page) do
    Page.goto!(page, "/logout", wait_until: :commit)

    Expect.to_be_visible!(Page.get_by_role(page, :heading, name: "Welcome to Plausible!"))
  end

  def add_site(opts) do
    page = Keyword.fetch!(opts, :page)
    domain = Keyword.fetch!(opts, :domain)

    Page.goto!(page, "/sites/new", wait_until: :commit)

    Expect.to_be_visible!(Page.get_by_role(page, :button, name: "Add site"))

    Page.get_by_label(page, "Domain") |> Locator.fill!(domain)

    Page.get_by_role(page, :button, name: "Add site") |> Locator.click!()

    Expect.to_have_url!(page, ~r/\/installation/)

    Expect.to_be_visible!(Page.get_by_role(page, :button, name: "I've installed it"))
  end

  def make_site_public(opts) do
    page = Keyword.fetch!(opts, :page)
    domain = Keyword.fetch!(opts, :domain)

    Page.goto!(page, "/#{domain}/settings/visibility", wait_until: :commit)

    page
    |> Page.get_by_role(:form, name: "Make stats publicly available")
    |> Locator.get_by_role(:button)
    |> Locator.click!()

    Expect.to_contain_text!(Page.locator(page, "body"), "are now public")
  end

  @doc "Returns the link."
  def create_shared_link(opts) do
    page = Keyword.fetch!(opts, :page)
    domain = Keyword.fetch!(opts, :domain)
    name = Keyword.fetch!(opts, :name)
    password = opts[:password]

    modal = Page.locator(page, "#shared-links-form-modal")
    table = Page.locator(page, "#shared-links-table")

    Page.goto!(page, "/#{domain}/settings/visibility", wait_until: :commit)
    expect_live_view_connected(page)

    Page.get_by_role(page, :button, name: "Add shared link") |> Locator.click!()

    modal |> Locator.get_by_label("Name") |> Locator.fill!(name)

    if password do
      modal |> Locator.locator("button#password-protect-") |> Locator.click!()

      modal |> Locator.locator("input#shared_link_password") |> Locator.fill!(password)
    end

    Page.get_by_role(page, :button, name: "Create shared link") |> Locator.click!()

    Expect.to_contain_text!(Page.locator(page, "body"), "Shared link saved")

    table
    |> Locator.locator("tr")
    |> Locator.filter(has_text: name)
    |> Locator.locator("input")
    |> Locator.input_value!()
  end

  def populate_stats(opts) do
    request = Keyword.fetch!(opts, :request)
    domain = Keyword.fetch!(opts, :domain)
    events = Keyword.fetch!(opts, :events)

    response =
      APIRequestContext.post!(request, "/e2e-tests/stats",
        headers: @json_headers,
        data: %{domain: domain, events: events}
      )

    assert APIResponse.ok(response)
  end

  def set_verification_scenario(opts) do
    request = Keyword.fetch!(opts, :request)
    domain = Keyword.fetch!(opts, :domain)
    scenario = Keyword.fetch!(opts, :scenario)

    response =
      APIRequestContext.put!(request, "/e2e-tests/verification",
        headers: @json_headers,
        data: %{domain: domain, scenario: scenario, options: opts[:options]}
      )

    assert APIResponse.ok(response)
  end

  @doc "`params` is a map of the goal's attributes."
  def add_goal(opts) do
    request = Keyword.fetch!(opts, :request)
    domain = Keyword.fetch!(opts, :domain)
    params = Keyword.fetch!(opts, :params)

    response =
      APIRequestContext.post!(request, "/e2e-tests/goal",
        headers: @json_headers,
        data: Map.merge(%{domain: domain}, Map.new(params))
      )

    assert APIResponse.ok(response)
  end

  # `click_manually` is useful when adding a goal for which there's no matching stat yet
  def add_custom_goal(opts) do
    page = Keyword.fetch!(opts, :page)
    domain = Keyword.fetch!(opts, :domain)
    name = Keyword.fetch!(opts, :name)
    display_name = opts[:display_name]
    currency = opts[:currency]
    click_manually = Keyword.get(opts, :click_manually, true)

    Page.goto!(page, "/#{domain}/settings/goals", wait_until: :commit)

    expect_live_view_connected(page)

    Page.get_by_role(page, :button, name: "Add goal") |> Locator.click!()
    custom_event_button = Page.locator(page, ~s|button[phx-value-goal-type="custom_events"]|)

    Locator.click!(custom_event_button)

    if click_manually do
      Page.get_by_role(page, :button, name: "Add manually") |> Locator.click!()
    end

    Expect.to_be_visible!(Page.get_by_role(page, :heading, name: "Add goal for #{domain}"))
    # NOTE: Locating inputs by role and label does not work in this case
    # for some reason.
    name_input = Page.locator(page, ~s|input[placeholder="e.g. Signup"]|)
    Locator.fill!(name_input, name)
    Page.locator(page, ~s|a[data-display-value="#{name}"]|) |> Locator.click!()
    Expect.to_have_attribute!(name_input, "value", name)

    if display_name do
      Page.locator(page, "input#custom_event_display_name_input") |> Locator.fill!(display_name)
    end

    if currency do
      Page.locator(page, ~s|button[aria-labelledby="enable-revenue-tracking"]|)
      |> Locator.click!()

      currency_input = Page.locator(page, "input[id^=currency_input_]")
      Locator.fill!(currency_input, currency)
      Page.locator(page, ~s|a[phx-value-submit-value="#{currency}"]|) |> Locator.click!()

      Expect.to_have_attribute!(
        Page.locator(page, ~s|input[name="goal[currency]"]|),
        "value",
        currency
      )
    end

    page
    |> Page.locator(~s|form[phx-submit="save-goal"]|)
    |> Locator.get_by_role(:button, name: "Add goal")
    |> Locator.click!()

    Expect.to_contain_text!(Page.locator(page, "body"), "Goal saved successfully")
  end

  def add_pageview_goal(opts) do
    page = Keyword.fetch!(opts, :page)
    domain = Keyword.fetch!(opts, :domain)
    pathname = Keyword.fetch!(opts, :pathname)
    display_name = opts[:display_name]

    Page.goto!(page, "/#{domain}/settings/goals", wait_until: :commit)

    expect_live_view_connected(page)

    Page.get_by_role(page, :button, name: "Add goal") |> Locator.click!()
    add_pageview_goal_button = Page.locator(page, ~s|button[phx-value-goal-type="pageviews"]|)

    Locator.click!(add_pageview_goal_button)

    Expect.to_be_visible!(Page.get_by_role(page, :heading, name: "Add goal for #{domain}"))

    pathname_input = Page.locator(page, ~s|input[id^="page_path_input"]|)
    Locator.fill!(pathname_input, pathname)
    Page.locator(page, ~s|a[data-display-value="#{pathname}"]|) |> Locator.click!()
    Expect.to_have_attribute!(pathname_input, "value", pathname)

    if display_name do
      Page.locator(page, "input#pageview_display_name_input") |> Locator.fill!(display_name)
    end

    page
    |> Page.locator(~s|form[phx-submit="save-goal"]|)
    |> Locator.get_by_role(:button, name: "Add goal")
    |> Locator.click!()

    Expect.to_contain_text!(Page.locator(page, "body"), "Goal saved successfully")
  end

  def add_scroll_depth_goal(opts) do
    page = Keyword.fetch!(opts, :page)
    domain = Keyword.fetch!(opts, :domain)
    pathname = Keyword.fetch!(opts, :pathname)
    display_name = opts[:display_name]
    scroll_percentage = opts[:scroll_percentage]

    Page.goto!(page, "/#{domain}/settings/goals", wait_until: :commit)

    expect_live_view_connected(page)

    Page.get_by_role(page, :button, name: "Add goal") |> Locator.click!()
    scroll_depth_event_button = Page.locator(page, ~s|button[phx-value-goal-type="scroll"]|)

    Locator.click!(scroll_depth_event_button)

    Expect.to_be_visible!(Page.get_by_role(page, :heading, name: "Add goal for #{domain}"))

    if scroll_percentage do
      Page.locator(page, ~s|input[name="goal[scroll_threshold]"]|)
      |> Locator.fill!(to_string(scroll_percentage))
    end

    pathname_input = Page.locator(page, ~s|input[id^="scroll_page_path_input"]|)
    Locator.fill!(pathname_input, pathname)
    Page.locator(page, ~s|a[data-display-value="#{pathname}"]|) |> Locator.click!()
    Expect.to_have_attribute!(pathname_input, "value", pathname)

    if display_name do
      Page.locator(page, "input#scroll_display_name_input") |> Locator.fill!(display_name)
    end

    page
    |> Page.locator(~s|form[phx-submit="save-goal"]|)
    |> Locator.get_by_role(:button, name: "Add goal")
    |> Locator.click!()

    Expect.to_contain_text!(Page.locator(page, "body"), "Goal saved successfully")
  end

  def add_custom_prop(opts) do
    page = Keyword.fetch!(opts, :page)
    domain = Keyword.fetch!(opts, :domain)
    name = Keyword.fetch!(opts, :name)

    Page.goto!(page, "/#{domain}/settings/properties", wait_until: :commit)

    expect_live_view_connected(page)

    Page.get_by_role(page, :button, name: "Add property") |> Locator.click!()

    Expect.to_be_visible!(Page.get_by_role(page, :heading, name: "Add property for #{domain}"))

    prop_input = Page.locator(page, "input#prop_input")
    Locator.fill!(prop_input, name)
    Page.locator(page, ~s|a[data-display-value="#{name}"]|) |> Locator.click!()
    Expect.to_have_attribute!(prop_input, "value", name)

    page
    |> Page.locator(~s|form[phx-submit="allow-prop"]|)
    |> Locator.get_by_role(:button, name: "Add property")
    |> Locator.click!()

    Expect.to_contain_text!(Page.locator(page, "body"), "Property added successfully")
  end

  def add_all_custom_props(opts) do
    page = Keyword.fetch!(opts, :page)
    domain = Keyword.fetch!(opts, :domain)

    Page.goto!(page, "/#{domain}/settings/properties", wait_until: :commit)

    expect_live_view_connected(page)

    Page.get_by_role(page, :button, name: "Add property") |> Locator.click!()

    Expect.to_be_visible!(Page.get_by_role(page, :heading, name: "Add property for #{domain}"))

    Page.get_by_text(page, ~r/Click to add [0-9]+ existing properties/) |> Locator.click!()

    Expect.to_contain_text!(Page.locator(page, "body"), "Properties added successfully")
  end

  def add_funnel(opts) do
    request = Keyword.fetch!(opts, :request)
    domain = Keyword.fetch!(opts, :domain)
    name = Keyword.fetch!(opts, :name)
    steps = Keyword.fetch!(opts, :steps)

    response =
      APIRequestContext.post!(request, "/e2e-tests/funnel",
        headers: @json_headers,
        data: %{domain: domain, name: name, steps: steps}
      )

    assert APIResponse.ok(response)
  end

  def get_funnel(opts) do
    request = Keyword.fetch!(opts, :request)
    domain = Keyword.fetch!(opts, :domain)
    name = Keyword.fetch!(opts, :name)

    response =
      APIRequestContext.get!(request, "/e2e-tests/funnel",
        headers: @json_headers,
        params: %{domain: domain, name: name}
      )

    assert APIResponse.ok(response)

    APIResponse.json!(response)
  end

  def subscribe_to_plan(opts) do
    page = Keyword.fetch!(opts, :page)
    plan_id = Keyword.fetch!(opts, :plan_id)

    Page.goto!(page, "/dev/billing/create-subscription-form/#{plan_id}", wait_until: :commit)

    Page.get_by_role(page, :link, name: "Subscribe to plan") |> Locator.click!()

    Expect.to_have_url!(page, ~r/\/settings\/billing\/subscription/)
  end

  @doc "Returns `%{domain:, user:}`."
  def setup_site(opts) do
    page = Keyword.fetch!(opts, :page)
    request = Keyword.fetch!(opts, :request)
    domain = opts[:domain] || "#{random_id()}.example.com"

    user =
      if opts[:user] do
        opts[:user]
      else
        user_id = random_id()

        user = %{
          name: "User #{user_id}",
          email: "email-#{user_id}@example.com",
          password: "VeryStrongVerySecret"
        }

        register(page: page, request: request, user: user)
        user
      end

    add_site(page: page, domain: domain)

    %{domain: domain, user: user}
  end
end
