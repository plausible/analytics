defmodule Plausible.Tracking do
  @api_host "https://api.amplitude.com"

  def event(conn, event, properties \\ %{}) do
    Task.start(fn ->
      track(Mix.env(), %{
        event_type: event,
        user_id: extract_user_id(conn),
        device_id: extract_device_id(conn),
        event_properties: properties,
        time: Timex.now() |> DateTime.to_unix
      })
    end)
  end

  def identify(conn, user_id, props \\ %{}) do
    Task.start(fn ->
      track(Mix.env(), %{
        event_type: "$identify",
        user_id: user_id,
        device_id: extract_device_id(conn),
        user_properties: props,
        time: Timex.now() |> DateTime.to_unix
      })
    end)
  end

  def track(:test, _params) do
    # /dev/null
  end

  def track(_, params) do
    HTTPoison.get!(@api_host <> "/httpapi", [], params: [api_key: api_key(), event: Jason.encode!(params)])
  end

  def api_identify(params) do
    HTTPoison.get!(@api_host <> "/identify", [], params: [api_key: api_key(), identification: Jason.encode!(params)])
  end

  defp extract_user_id(conn) do
    if conn.assigns[:current_user] do
      conn.assigns[:current_user].id
    end
  end

  defp extract_device_id(conn) do
    Plug.Conn.get_session(conn, :device_id)
  end

  defp api_key, do: Keyword.fetch!(Application.get_env(:plausible, :amplitude), :api_key)
end
