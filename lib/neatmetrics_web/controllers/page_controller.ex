defmodule NeatmetricsWeb.PageController do
  use NeatmetricsWeb, :controller
  use Neatmetrics.Repo
  @half_hour_in_seconds 30 * 60

  def index(conn, _params) do
    if get_session(conn, :current_user_email) do
      user = Neatmetrics.Repo.get_by!(Neatmetrics.Auth.User, email: get_session(conn, :current_user_email))
             |> Neatmetrics.Repo.preload(:sites)
      render(conn, "sites.html", sites: user.sites)
    else
      render(conn, "index.html")
    end
  end

  def logout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: "/")
  end

  def onboarding(conn, _params) do
    if get_session(conn, :current_user_email) do
      user = Neatmetrics.Repo.get_by!(Neatmetrics.Auth.User, email: get_session(conn, :current_user_email))
             |> Neatmetrics.Repo.preload(:sites)

      case user.sites do
        [] ->
          render(conn, "onboarding_create_site.html")
        [site] ->
          render(conn, "onboarding_add_tracking.html", site: site)
        [site | rest] ->
          send_resp(conn, 400, "Already onboarded")
      end
    else
      render(conn, "onboarding_enter_email.html")
    end
  end

  def create_site(conn, %{"domain" => domain}) do
    site_changeset = Neatmetrics.Site.changeset(%Neatmetrics.Site{}, %{domain: domain})
    user = Neatmetrics.Repo.get_by!(Neatmetrics.Auth.User, email: get_session(conn, :current_user_email))

    {:ok, %{site: site}} = Ecto.Multi.new()
    |> Ecto.Multi.insert(:site, site_changeset)
    |>  Ecto.Multi.run(:site_membership, fn repo, %{site: site} ->
      membership_changeset = Neatmetrics.Site.Membership.changeset(%Neatmetrics.Site.Membership{}, %{
        site_id: site.id,
        user_id: user.id
      })
      repo.insert(membership_changeset)
    end)
    |> Repo.transaction

    redirect(conn, to: "/onboarding")
  end

  def send_login_link(conn, %{"email" => email}) do
    token = Phoenix.Token.sign(NeatmetricsWeb.Endpoint, "email_login", %{email: email})
    IO.puts(NeatmetricsWeb.Endpoint.url() <> "/claim-login?token=#{token}")
    conn |> send_resp(200, "We've sent a magic link to #{email}. You can use it to log in by clicking on it.")
  end

  def login_form(conn, _params) do
    conn
    |> render("login_form.html")
  end

  defp successful_login(email) do
    found_user = Repo.get_by(Neatmetrics.Auth.User, email: email)
    if found_user do
      :found
    else
      Neatmetrics.Auth.User.changeset(%Neatmetrics.Auth.User{}, %{email: email})
        |> Neatmetrics.Repo.insert!
      :new
    end
  end

  def claim_login_link(conn, %{"token" => token}) do
    case Phoenix.Token.verify(NeatmetricsWeb.Endpoint, "email_login", token, max_age: @half_hour_in_seconds) do
      {:ok, %{email: email}} ->
        conn = put_session(conn, :current_user_email, email)

        case successful_login(email) do
          :new ->
            redirect(conn, to: "/onboarding")
          :found ->
            redirect(conn, to: "/")
        end
      {:error, :expired} ->
        conn |> send_resp(401, "Your login token has expired")
      {:error, _} ->
        conn |> send_resp(400, "Your login token is invalid")
    end
  end

  def analytics(conn, %{"website" => website} = params) do
    {period, date_range} = get_date_range(params)

    pageviews = Repo.all(
      from p in Neatmetrics.Pageview,
      where: p.hostname == ^website,
      where: type(p.inserted_at, :date) >= ^date_range.first and type(p.inserted_at, :date) <= ^date_range.last
    )

    pageview_groups = Enum.group_by(pageviews, fn pageview -> NaiveDateTime.to_date(pageview.inserted_at) end)

    plot = Enum.map(date_range, fn day ->
      Enum.count(pageview_groups[day] || [])
    end)

    labels = Enum.map(date_range, fn date ->
      Timex.format!(date, "{WDshort} {D} {Mshort}")
    end)

    user_agents = pageviews
      |> Enum.filter(fn pv -> pv.user_agent && pv.new_visitor end)
      |> Enum.map(fn pv -> UAInspector.parse_client(pv.user_agent) end)

    device_types = user_agents
      |> Enum.group_by(&device_type/1)
      |> Enum.map(fn {page, views} -> {page, Enum.count(views)} end)
      |> Enum.sort(fn ({_, v1}, {_, v2}) -> v1 > v2 end)
      |> Enum.take(5)

    browsers = user_agents
      |> Enum.group_by(&browser_name/1)
      |> Enum.map(fn {page, views} -> {page, Enum.count(views)} end)
      |> Enum.sort(fn ({_, v1}, {_, v2}) -> v1 > v2 end)
      |> Enum.take(5)

    operating_systems = user_agents
      |> Enum.group_by(&operating_system/1)
      |> Enum.map(fn {page, views} -> {page, Enum.count(views)} end)
      |> Enum.sort(fn ({_, v1}, {_, v2}) -> v1 > v2 end)
      |> Enum.take(5)

    top_referrers = pageviews
      |> Enum.filter(fn pv -> pv.referrer && pv.new_visitor && !String.contains?(pv.referrer, pv.hostname) end)
      |> Enum.map(&(RefInspector.parse(&1.referrer)))
      |> Enum.group_by(&(&1.source))
      |> Enum.map(fn {ref, views} -> {ref, Enum.count(views)} end)
      |> Enum.sort(fn ({_, v1}, {_, v2}) -> v1 > v2 end)
      |> Enum.take(5)

    top_pages = Enum.group_by(pageviews, &(&1.pathname))
      |> Enum.map(fn {page, views} -> {page, Enum.count(views)} end)
      |> Enum.sort(fn ({_, v1}, {_, v2}) -> v1 > v2 end)
      |> Enum.take(5)

    top_screen_sizes = Enum.group_by(pageviews, &Neatmetrics.Pageview.screen_string/1)
      |> Enum.map(fn {page, views} -> {page, Enum.count(views)} end)
      |> Enum.sort(fn ({_, v1}, {_, v2}) -> v1 > v2 end)
      |> Enum.take(5)

    render(conn, "analytics.html",
      plot: plot,
      labels: labels,
      pageviews: Enum.count(pageviews),
      unique_visitors: Enum.filter(pageviews, fn pv -> pv.new_visitor end) |> Enum.count,
      top_referrers: top_referrers,
      top_pages: top_pages,
      top_screen_sizes: top_screen_sizes,
      device_types: device_types,
      browsers: browsers,
      operating_systems: operating_systems,
      hostname: website,
      title: "Neatmetrics · " <> website,
      selected_period: period
    )
  end

  defp get_date_range(%{"period" => "today"}) do
    date_range = Date.range(Timex.today(), Timex.today())
    {"today", date_range}
  end

  defp get_date_range(%{"period" => "7days"}) do
    start_date = Timex.shift(Timex.today(), days: -7)
    date_range = Date.range(start_date, Timex.today())
    {"7days", date_range}
  end

  defp get_date_range(%{"period" => "30days"}) do
    start_date = Timex.shift(Timex.today(), days: -30)
    date_range = Date.range(start_date, Timex.today())
    {"30days", date_range}
  end

  defp get_date_range(_) do
    get_date_range(%{"period" => "30days"})
  end

  defp browser_name(ua) do
    case ua.client do
      %UAInspector.Result.Client{name: "Mobile Safari"} -> "Safari"
      %UAInspector.Result.Client{name: "Chrome Mobile"} -> "Chrome"
      %UAInspector.Result.Client{name: "Chrome Mobile iOS"} -> "Chrome"
      %UAInspector.Result.Client{type: "mobile app"} -> "Mobile App"
      client -> client.name
    end
  end

  defp device_type(ua) do
    case ua.device do
      :unknown -> "unknown"
      device -> device.type
    end
  end

  defp operating_system(ua) do
    ua.os.name
  end
end
