defmodule PlausibleWeb.SiteController do
  use PlausibleWeb, :controller
  use Plausible.Repo

  plug :require_account when action not in [:index, :privacy, :terms, :analytics]

  def new(conn, _params) do
    changeset = Plausible.Site.changeset(%Plausible.Site{})

    render(conn, "new.html", changeset: changeset)
  end

  defp insert_site(user_id, params) do
    site_changeset = Plausible.Site.changeset(%Plausible.Site{}, params)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:site, site_changeset)
    |>  Ecto.Multi.run(:site_membership, fn repo, %{site: site} ->
      membership_changeset = Plausible.Site.Membership.changeset(%Plausible.Site.Membership{}, %{
        site_id: site.id,
        user_id: user_id
      })
      repo.insert(membership_changeset)
    end)
    |> Repo.transaction
  end

  def add_snippet(conn, %{"website" => website}) do
    site = Plausible.Repo.get_by!(Plausible.Site, domain: website)
    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("snippet.html", site: site)
  end

  def create_site(conn, %{"site" => site_params}) do
    case insert_site(conn.assigns[:current_user].id, site_params) do
      {:ok, %{site: site}} ->
        redirect(conn, to: "/#{site.domain}/snippet")
      {:error, :site, changeset, _} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  defp show_analytics(conn, site, total_pageviews) do
    {period, date_range} = get_date_range(site, conn.params)

    base_query = from(p in Plausible.Pageview,
      where: p.hostname == ^site.domain,
      where: type(fragment("(? at time zone 'utc' at time zone ?)", p.inserted_at, ^site.timezone), :date) >= ^date_range.first and type(fragment("(? at time zone 'utc' at time zone ?)", p.inserted_at, ^site.timezone), :date) <= ^date_range.last
    )

    pageview_groups = Repo.all(
      from p in base_query,
      group_by: 1,
      order_by: 1,
      select: {type(fragment("(? at time zone 'utc' at time zone ?)", p.inserted_at, ^site.timezone), :date), count(p.id)}
    ) |> Enum.into(%{})

    plot = Enum.map(date_range, fn day ->
      pageview_groups[day] || 0
    end)

    labels = Enum.map(date_range, fn date ->
      Timex.format!(date, "{D} {Mshort}")
    end)

    unique_visitors = Repo.aggregate(from(
      p in base_query,
      where: p.new_visitor
    ), :count, :id)

    device_types = Repo.all(from p in base_query,
      select: {p.device_type, count(p.device_type)},
      group_by: p.device_type,
      where: p.new_visitor == true,
      order_by: [desc: count(p.device_type)],
      limit: 5
    )

    browsers = Repo.all(from p in base_query,
      select: {p.browser, count(p.browser)},
      group_by: p.browser,
      where: p.new_visitor == true,
      order_by: [desc: count(p.browser)],
      limit: 5
    )

    operating_systems = Repo.all(from p in base_query,
      select: {p.operating_system, count(p.operating_system)},
      group_by: p.operating_system,
      where: p.new_visitor == true,
      order_by: [desc: count(p.operating_system)],
      limit: 5
    )

    top_referrers = Repo.all(from p in base_query,
      select: {p.referrer_source, count(p.referrer_source)},
      group_by: p.referrer_source,
      where: p.new_visitor == true and not is_nil(p.referrer_source),
      order_by: [desc: count(p.referrer_source)],
      limit: 5
    )

    top_pages = Repo.all(from p in base_query,
      select: {p.pathname, count(p.pathname)},
      group_by: p.pathname,
      order_by: [desc: count(p.pathname)],
      limit: 5
    )

    top_screen_sizes = Repo.all(from p in base_query,
      select: {p.screen_size, count(p.screen_size)},
      group_by: p.screen_size,
      order_by: [desc: count(p.screen_size)],
      limit: 5
    )

		conn
    |> assign(:skip_plausible_tracking, true)
    |> render("analytics.html",
      plot: plot,
      labels: labels,
      pageviews: total_pageviews,
      unique_visitors: unique_visitors,
      top_referrers: top_referrers,
      top_pages: top_pages,
      top_screen_sizes: top_screen_sizes,
      device_types: device_types,
      browsers: browsers,
      operating_systems: operating_systems,
      hostname: site.domain,
      title: "Plausible · " <> site.domain,
      selected_period: period
    )
  end

  def analytics(conn, %{"website" => website} = params) do
    site = Repo.get_by(Plausible.Site, domain: website)

    if site && current_user_can_access?(conn, site) do
      {_period, date_range} = get_date_range(site, params)

      pageviews = Repo.aggregate(
        from(p in Plausible.Pageview,
        where: p.hostname == ^website,
        where: type(p.inserted_at, :date) >= ^date_range.first and type(p.inserted_at, :date) <= ^date_range.last
      ), :count, :id)

      if pageviews == 0 do
        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("waiting_first_pageview.html", site: site)
      else
        show_analytics(conn, site, pageviews)
      end
    else
      conn |> send_resp(404, "Website not found")
    end
  end

  defp current_user_can_access?(_conn, %Plausible.Site{domain: "gigride.live"}) do
    true
  end

  defp current_user_can_access?(conn, site) do
    case get_session(conn, :current_user_email) do
      nil -> false
      email ->
        user = Repo.get_by(Plausible.Auth.User, email: email)
        |> Repo.preload(:sites)

        Enum.any?(user.sites, fn user_site -> user_site == site end)
    end
  end

  defp get_date_range(site, %{"period" => "today"}) do
    date_range = Date.range(today(site), today(site))
    {"today", date_range}
  end

  defp get_date_range(site, %{"period" => "7days"}) do
    start_date = Timex.shift(today(site), days: -7)
    date_range = Date.range(start_date, today(site))
    {"7days", date_range}
  end

  defp get_date_range(site, %{"period" => "30days"}) do
    start_date = Timex.shift(today(site), days: -30)
    date_range = Date.range(start_date, today(site))
    {"30days", date_range}
  end

  defp get_date_range(site, _) do
    get_date_range(site, %{"period" => "7days"})
  end

  defp today(site) do
    Timex.now(site.timezone) |> Timex.to_date
  end

  defp require_account(conn, _opts) do
    case get_session(conn, :current_user_email) do
      nil ->
        redirect(conn, to: "/login") |> Plug.Conn.halt
      _email ->
        conn
    end
  end
end
