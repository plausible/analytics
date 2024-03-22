defmodule PlausibleWeb.Plugins.API.Controllers.Goals do
  @moduledoc """
  Controller for the Goal resource under Plugins API
  """
  use PlausibleWeb, :plugins_api_controller

  operation(:create,
    id: "Goal.GetOrCreate",
    summary: "Get or create Goal",
    request_body: {"Goal params", "application/json", Schemas.Goal.CreateRequest},
    responses: %{
      created: {"Goal", "application/json", Schemas.Goal.ListResponse},
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

    goal_or_goals =
      case body_params do
        %{goals: goals} -> goals
        %{goal: _} = single_goal -> single_goal
      end

    case API.Goals.create(site, goal_or_goals) do
      {:ok, goals} ->
        location_headers =
          Enum.map(goals, &{"location", plugins_api_goals_url(conn, :get, &1.id)})

        conn
        |> prepend_resp_headers(location_headers)
        |> put_view(Views.Goal)
        |> put_status(:created)
        |> render("index.json", goals: goals, authorized_site: site)

      {:error, :upgrade_required} ->
        payment_required(conn)

      {:error, changeset} ->
        Errors.error(conn, 422, changeset)
    end
  end

  operation(:index,
    summary: "Retrieve Goals",
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
      ok: {"Goals response", "application/json", Schemas.Goal.ListResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Unauthorized}
    }
  )

  @spec index(Plug.Conn.t(), %{}) :: Plug.Conn.t()
  def index(conn, _params) do
    {:ok, pagination} = API.Goals.get_goals(conn.assigns.authorized_site, conn.query_params)

    conn
    |> put_view(Views.Goal)
    |> render("index.json", %{pagination: pagination})
  end

  operation(:get,
    summary: "Retrieve Goal by ID",
    parameters: [
      id: [
        in: :path,
        type: :integer,
        description: "Goal ID",
        example: 123,
        required: true
      ]
    ],
    responses: %{
      ok: {"Goal", "application/json", Schemas.Goal},
      not_found: {"NotFound", "application/json", Schemas.NotFound},
      unauthorized: {"Unauthorized", "application/json", Schemas.Unauthorized},
      unprocessable_entity:
        {"Unprocessable entity", "application/json", Schemas.UnprocessableEntity}
    }
  )

  @spec get(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def get(%{private: %{open_api_spex: %{params: %{id: id}}}} = conn, _params) do
    site = conn.assigns.authorized_site

    case API.Goals.get(site, id) do
      nil ->
        conn
        |> put_view(Views.Error)
        |> put_status(:not_found)
        |> render("404.json")

      goal ->
        conn
        |> put_view(Views.Goal)
        |> put_status(:ok)
        |> render("goal.json", goal: goal, authorized_site: site)
    end
  end

  operation(:delete,
    summary: "Delete Goal by ID",
    parameters: [
      id: [
        in: :path,
        type: :integer,
        description: "Goal ID",
        example: 123,
        required: true
      ]
    ],
    responses: %{
      no_content: {"NoContent", nil, nil},
      unauthorized: {"Unauthorized", "application/json", Schemas.Unauthorized}
    }
  )

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(%{private: %{open_api_spex: %{params: %{id: id}}}} = conn, _params) do
    :ok = API.Goals.delete(conn.assigns.authorized_site, id)
    send_resp(conn, :no_content, "")
  end

  operation(:delete_bulk,
    id: "Goal.DeleteBulk",
    summary: "Delete Goals in bulk",
    request_body: {"Goal params", "application/json", Schemas.Goal.DeleteBulkRequest},
    responses: %{
      no_content: {"NoContent", nil, nil},
      unauthorized: {"Unauthorized", "application/json", Schemas.Unauthorized}
    }
  )

  @spec delete_bulk(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete_bulk(
        %{private: %{open_api_spex: %{body_params: %{goal_ids: goal_ids}}}} = conn,
        _params
      ) do
    :ok = API.Goals.delete(conn.assigns.authorized_site, goal_ids)
    send_resp(conn, :no_content, "")
  end

  defp payment_required(conn) do
    Errors.error(
      conn,
      402,
      "#{Plausible.Billing.Feature.RevenueGoals.display_name()} is part of the Plausible Business plan. To get access to this feature, please upgrade your account."
    )
  end
end
