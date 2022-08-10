defmodule Plausible.Ingestion.Request do
  defstruct ~w(remote_ip params query_params user_agent)a

  @type t() :: %__MODULE__{
          remote_ip: String.t() | nil,
          params: map(),
          query_params: map(),
          user_agent: String.t() | nil
        }

  @allowed_query_params ~w(utm_medium utm_source utm_campaign utm_content utm_term utm_source source ref)

  @spec build(Plug.Conn.t()) :: {:ok, t()} | {:error, :invalid_json}
  @doc """
  Builds a %Plausible.Ingestion.Request{} struct from %Plug.Conn{}.
  """
  def build(%Plug.Conn{} = conn) do
    with {:ok, body} <- parse_body(conn),
         %{} = params <- build_params(body),
         %{} = query_params <- decode_query_params(params),
         remote_ip <- PlausibleWeb.RemoteIp.get(conn) do
      %__MODULE__{}
      |> Map.put(:remote_ip, remote_ip)
      |> Map.put(:params, params)
      |> Map.put(:query_params, query_params)
      |> put_user_agent(conn)
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

  defp build_params(body) do
    %{
      name: body["n"] || body["name"],
      url: body["u"] || body["url"],
      referrer: body["r"] || body["referrer"],
      domain: body["d"] || body["domain"],
      screen_width: body["w"] || body["screen_width"],
      hash_mode: body["h"] || body["hashMode"],
      meta: parse_meta(body)
    }
  end

  defp parse_meta(params) do
    raw_meta = params["m"] || params["meta"] || params["p"] || params["props"]

    case decode_raw_props(raw_meta) do
      {:ok, parsed_json} ->
        Enum.filter(parsed_json, fn
          {_, ""} -> false
          {_, nil} -> false
          {_, val} when is_list(val) -> false
          {_, val} when is_map(val) -> false
          _ -> true
        end)
        |> Map.new()

      _ ->
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

  defp decode_query_params(params) do
    with url when is_binary(url) <- params.url,
         %URI{query: query} when is_binary(query) <- URI.parse(url) do
      do_decode_query_params(query)
    else
      _any -> %{}
    end
  end

  defp do_decode_query_params(query) do
    try do
      query
      |> URI.query_decoder()
      |> Enum.reduce(%{}, fn
        {key, value}, acc when key in @allowed_query_params -> Map.put(acc, key, value)
        _any, acc -> acc
      end)
    rescue
      _ -> %{}
    end
  end

  defp put_user_agent(%__MODULE__{} = request, %Plug.Conn{} = conn) do
    user_agent =
      conn
      |> Plug.Conn.get_req_header("user-agent")
      |> List.first()

    %__MODULE__{request | user_agent: user_agent}
  end
end
