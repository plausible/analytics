defmodule PlausibleWeb.Api.InternalController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Stats.Clickhouse, as: Stats
  import PlausibleWeb.Api.Helpers
  import Phoenix.Pagination.JSON

  def domain_status(conn, %{"domain" => domain}) do
    if Stats.has_pageviews?(%Plausible.Site{domain: domain}) do
      json(conn, "READY")
    else
      json(conn, "WAITING")
    end
  end

  def sites(conn, params) do
    current_user = conn.assigns[:current_user]

    if current_user do
      sites =
        sitesFor(current_user, params)
        |> buildResponse(conn)

      json(conn, sites)
    else
      unauthorized(conn, "You need to be logged in to request a list of sites")
    end
  end

  defp sitesFor(user, params) do
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
      pagination: paginate(conn, pagination)
    }
  end
end
