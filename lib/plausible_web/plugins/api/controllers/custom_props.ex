defmodule PlausibleWeb.Plugins.API.Controllers.CustomProps do
  @moduledoc """
  Controller for the CustomProp resource under Plugins API
  """
  use PlausibleWeb, :plugins_api_controller

  operation(:enable,
    id: "CustomProp.GetOrEnable",
    summary: "Get or enable CustomProp(s)",
    request_body:
      {"CustomProp enable params", "application/json", Schemas.CustomProp.EnableRequest},
    responses: %{
      created: {"CustomProp", "application/json", Schemas.CustomProp.ListResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Unauthorized},
      payment_required: {"Payment required", "application/json", Schemas.PaymentRequired},
      unprocessable_entity:
        {"Unprocessable entity", "application/json", Schemas.UnprocessableEntity}
    }
  )

  @spec enable(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def enable(
        %{private: %{open_api_spex: %{body_params: body_params}}} = conn,
        _params
      ) do
    site = conn.assigns.authorized_site

    prop_or_props =
      case body_params do
        %{custom_props: props} ->
          Enum.map(props, & &1.custom_prop.key)

        %{custom_prop: %{key: prop}} ->
          prop
      end

    case API.CustomProps.enable(site, prop_or_props) do
      {:ok, enabled_props} ->
        conn
        |> put_view(Views.CustomProp)
        |> put_status(:created)
        |> render("index.json", props: enabled_props, authorized_site: site)

      {:error, :upgrade_required} ->
        payment_required(conn)

      {:error, changeset} ->
        Errors.error(conn, 422, changeset)
    end
  end

  operation(:disable,
    id: "CustomProp.DisableBulk",
    summary: "Disable CustomProp(s)",
    request_body:
      {"CustomProp disable params", "application/json", Schemas.CustomProp.DisableRequest},
    responses: %{
      no_content: {"NoContent", nil, nil},
      unauthorized: {"Unauthorized", "application/json", Schemas.Unauthorized},
      payment_required: {"Payment required", "application/json", Schemas.PaymentRequired},
      unprocessable_entity:
        {"Unprocessable entity", "application/json", Schemas.UnprocessableEntity}
    }
  )

  @spec disable(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def disable(
        %{private: %{open_api_spex: %{body_params: body_params}}} = conn,
        _params
      ) do
    site = conn.assigns.authorized_site

    prop_or_props =
      case body_params do
        %{custom_props: props} ->
          Enum.map(props, & &1.custom_prop.key)

        %{custom_prop: %{key: prop}} ->
          prop
      end

    case API.CustomProps.disable(site, prop_or_props) do
      :ok ->
        send_resp(conn, :no_content, "")

      {:error, changeset} ->
        Errors.error(conn, 422, changeset)
    end
  end

  defp payment_required(conn) do
    Errors.error(
      conn,
      402,
      "#{Plausible.Billing.Feature.Props.display_name()} is part of the Plausible Business plan. To get access to this feature, please upgrade your account."
    )
  end
end
