defmodule PlausibleWeb.Api.InternalController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Stats.Clickhouse, as: Stats

  def domain_status(conn, %{"domain" => domain}) do
    site = Plausible.Sites.get_by_domain(domain)

    if Stats.has_pageviews?(site) do
      json(conn, "READY")
    else
      json(conn, "WAITING")
    end
  end

  def sites(conn, params) do
    current_user = conn.assigns[:current_user]

    if current_user do
      sites =
        sites_for(current_user, params)
        |> buildResponse(conn)

      json(conn, sites)
    else
      PlausibleWeb.Api.Helpers.unauthorized(
        conn,
        "You need to be logged in to request a list of sites"
      )
    end
  end

  defp sites_for(user, params) do
    Repo.paginate(
      from(
        s in Plausible.Site,
        join: sm in Plausible.Site.Membership,
        on: sm.site_id == s.id,
        where: sm.user_id == ^user.id,
        order_by: s.domain
      ),
      params
    )
  end

  defp buildResponse({sites, pagination}, conn) do
    %{
      data: Enum.map(sites, &%{domain: &1.domain}),
      pagination: Phoenix.Pagination.JSON.paginate(conn, pagination)
    }
  end
end
