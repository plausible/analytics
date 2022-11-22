defmodule Plausible.Ingestion.Request do
  @moduledoc """
  The %Plausible.Ingestion.Request{} struct stores all needed fields to create an event downstream.
  """

  defstruct [
    :remote_ip,
    :user_agent,
    :event_name,
    :uri,
    :referrer,
    :domains,
    :screen_width,
    :hash_mode,
    props: %{},
    query_params: %{}
  ]

  @type t() :: %__MODULE__{
          remote_ip: String.t() | nil,
          user_agent: String.t() | nil,
          event_name: term(),
          uri: URI.t() | nil,
          referrer: term(),
          domains: list(String.t()),
          screen_width: term(),
          hash_mode: term(),
          props: map(),
          query_params: map()
        }

  @spec build(Plug.Conn.t()) :: {:ok, t()} | {:error, :invalid_json}
  @doc """
  Builds a list of %Plausible.Ingestion.Request{} struct from %Plug.Conn{}.
  """
  def build(%Plug.Conn{} = conn) do
    with {:ok, request_body} <- parse_body(conn) do
      %__MODULE__{}
      |> Map.put(:remote_ip, PlausibleWeb.RemoteIp.get(conn))
      |> put_uri(request_body)
      |> put_user_agent(conn)
      |> put_request_params(request_body)
      |> put_query_params()
      |> map_domains(request_body)
      |> then(&{:ok, &1})
    end
  end

  defp parse_body(conn) do
    case conn.body_params do
      %Plug.Conn.Unfetched{} ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)

        case Jason.decode(body) do
          {:ok, params} -> {:ok, params}
          _ -> {:error, :invalid_json}
        end

      params ->
        {:ok, params}
    end
  end

  defp put_request_params(%__MODULE__{} = request, %{} = request_body) do
    %__MODULE__{
      request
      | event_name: request_body["n"] || request_body["name"],
        referrer: request_body["r"] || request_body["referrer"],
        screen_width: request_body["w"] || request_body["screen_width"],
        hash_mode: request_body["h"] || request_body["hashMode"],
        props: parse_props(request_body)
    }
  end

  defp map_domains(%__MODULE__{} = request, %{} = request_body) do
    domains =
      if raw = request_body["d"] || request_body["domain"] do
        raw
        |> String.split(",")
        |> Enum.map(&sanitize_hostname/1)
      else
        [sanitize_hostname(request.uri)]
      end

    %__MODULE__{request | domains: domains}
  end

  defp put_uri(%__MODULE__{} = request, %{} = request_body) do
    if url = request_body["u"] || request_body["url"] do
      %__MODULE__{request | uri: URI.parse(url)}
    else
      request
    end
  end

  defp parse_props(%{} = request_body) do
    raw_props =
      request_body["m"] || request_body["meta"] || request_body["p"] || request_body["props"]

    case decode_raw_props(raw_props) do
      {:ok, parsed_json} ->
        parsed_json
        |> Enum.filter(&valid_prop_value?/1)
        |> Map.new()

      _error ->
        %{}
    end
  end

  defp decode_raw_props(props) when is_map(props), do: {:ok, props}

  defp decode_raw_props(raw_json) when is_binary(raw_json) do
    case Jason.decode(raw_json) do
      {:ok, parsed_props} when is_map(parsed_props) ->
        {:ok, parsed_props}

      _ ->
        :not_a_map
    end
  end

  defp decode_raw_props(_), do: :bad_format

  defp valid_prop_value?({key, value}) do
    case {key, value} do
      {_key, ""} -> false
      {_key, nil} -> false
      {_key, value} when is_list(value) -> false
      {_key, value} when is_map(value) -> false
      {_key, _value} -> true
    end
  end

  defp put_query_params(%__MODULE__{} = request) do
    case request do
      %__MODULE__{uri: %URI{query: query}} when is_binary(query) ->
        %__MODULE__{request | query_params: URI.decode_query(query)}

      _any ->
        request
    end
  end

  defp put_user_agent(%__MODULE__{} = request, %Plug.Conn{} = conn) do
    user_agent =
      conn
      |> Plug.Conn.get_req_header("user-agent")
      |> List.first()

    %__MODULE__{request | user_agent: user_agent}
  end

  @doc """
  Removes the "www" part of a hostname.
  """
  def sanitize_hostname(%URI{host: hostname}) do
    sanitize_hostname(hostname)
  end

  def sanitize_hostname(hostname) when is_binary(hostname) do
    hostname
    |> String.trim()
    |> String.replace_prefix("www.", "")
  end

  def sanitize_hostname(nil) do
    nil
  end
end
