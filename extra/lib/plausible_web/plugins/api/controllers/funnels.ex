defmodule PlausibleWeb.Plugins.API.Controllers.Funnels do
  @moduledoc """
  Controller for the Funnel resource under Plugins API
  """
  use PlausibleWeb, :plugins_api_controller

  operation(:create,
    id: "Funnel.GetOrCreate",
    summary: "Get or create Funnel",
    request_body: {"Funnel params", "application/json", Schemas.Funnel.CreateRequest},
    responses: %{
      created: {"Funnel", "application/json", Schemas.Funnel},
      unauthorized: {"Unauthorized", "application/json", Schemas.Unauthorized},
      payment_required: {"Payment required", "application/json", Schemas.PaymentRequired},
      unprocessable_entity:
        {"Unprocessable entity", "application/json", Schemas.UnprocessableEntity}
    }
  )

  def create(
        %{private: %{open_api_spex: %{body_params: body_params}}} = conn,
        _params
      ) do
    site = conn.assigns.authorized_site

    case Plausible.Plugins.API.Funnels.create(site, body_params) do
      {:ok, funnel} ->
        headers = [{"location", plugins_api_funnels_url(conn, :get, funnel.id)}]

        conn
        |> prepend_resp_headers(headers)
        |> put_view(Views.Funnel)
        |> put_status(:created)
        |> render("funnel.json", funnel: funnel, authorized_site: site)

      {:error, :upgrade_required} ->
        payment_required(conn)

      {:error, changeset} ->
        Errors.error(conn, 422, changeset)
    end
  end

  operation(:index,
    summary: "Retrieve Funnels",
    parameters: [
      limit: [in: :query, type: :integer, description: "Maximum entries per page", example: 10],
      after: [
        in: :query,
        type: :string,
        description: "Cursor value to seek after - generated internally"
      ],
      before: [
        in: :query,
        type: :string,
        description: "Cursor value to seek before - generated internally"
      ]
    ],
    responses: %{
      ok: {"Funnels response", "application/json", Schemas.Funnel.ListResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Unauthorized}
    }
  )

  @spec index(Plug.Conn.t(), %{}) :: Plug.Conn.t()
  def index(conn, _params) do
    {:ok, pagination} = API.Funnels.get_funnels(conn.assigns.authorized_site, conn.query_params)

    conn
    |> put_view(Views.Funnel)
    |> render("index.json", %{pagination: pagination})
  end

  operation(:get,
    summary: "Retrieve Funnel by ID",
    parameters: [
      id: [
        in: :path,
        type: :integer,
        description: "Funnel ID",
        example: 123,
        required: true
      ]
    ],
    responses: %{
      ok: {"Goal", "application/json", Schemas.Funnel},
      not_found: {"NotFound", "application/json", Schemas.NotFound},
      unauthorized: {"Unauthorized", "application/json", Schemas.Unauthorized},
      unprocessable_entity:
        {"Unprocessable entity", "application/json", Schemas.UnprocessableEntity}
    }
  )

  @spec get(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def get(%{private: %{open_api_spex: %{params: %{id: id}}}} = conn, _params) do
    site = conn.assigns.authorized_site

    case API.Funnels.get(site, id) do
      nil ->
        conn
        |> put_view(Views.Error)
        |> put_status(:not_found)
        |> render("404.json")

      funnel ->
        conn
        |> put_view(Views.Funnel)
        |> put_status(:ok)
        |> render("funnel.json", funnel: funnel, authorized_site: site)
    end
  end

  defp payment_required(conn) do
    Errors.error(
      conn,
      402,
      "#{Plausible.Billing.Feature.Funnels.display_name()} is part of the Plausible Business plan. To get access to this feature, please upgrade your account."
    )
  end
end
