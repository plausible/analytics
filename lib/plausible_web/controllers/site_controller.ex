defmodule PlausibleWeb.SiteController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Analytics

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

  defp show_analytics(conn, site) do
    {date_range, step_type} = get_date_range(site, conn.params)

    query = Analytics.Query.new(
      date_range: date_range,
      step_type: step_type
    )

    plot = Analytics.calculate_plot(site, query)
    labels = Analytics.labels(site, query)

		conn
    |> assign(:skip_plausible_tracking, true)
    |> render("analytics.html",
      plot: plot,
      labels: labels,
      pageviews: Analytics.total_pageviews(site, query),
      unique_visitors: Analytics.unique_visitors(site, query),
      top_referrers: Analytics.top_referrers(site, query),
      top_pages: Analytics.top_pages(site, query),
      top_screen_sizes: Analytics.top_screen_sizes(site, query),
      device_types: Analytics.device_types(site, query),
      browsers: Analytics.browsers(site, query),
      operating_systems: Analytics.operating_systems(site, query),
      site: site,
      title: "Plausible · " <> site.domain
    )
  end

  def analytics(conn, %{"website" => website} = params) do
    site = Repo.get_by(Plausible.Site, domain: website)

    if site && current_user_can_access?(conn, site) do
      {date_range, _step} = get_date_range(site, params)

      has_pageviews = Repo.exists?(
        from p in Plausible.Pageview,
        where: p.hostname == ^website
      )

      if has_pageviews do
        show_analytics(conn, site)
      else
        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("waiting_first_pageview.html", site: site)
      end
    else
      conn |> send_resp(404, "Website not found")
    end
  end

  defp current_user_can_access?(_conn, %Plausible.Site{domain: "plausible.io"}) do
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
    {date_range, "hour"}
  end

  defp get_date_range(site, %{"period" => "7days"}) do
    start_date = Timex.shift(today(site), days: -7)
    date_range = Date.range(start_date, today(site))
    {date_range, "date"}
  end

  defp get_date_range(site, %{"period" => "30days"}) do
    start_date = Timex.shift(today(site), days: -30)
    date_range = Date.range(start_date, today(site))
    {date_range, "date"}
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
