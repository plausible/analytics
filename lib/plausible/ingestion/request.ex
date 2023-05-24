defmodule Plausible.Ingestion.Request do
  @moduledoc """
  The %Plausible.Ingestion.Request{} struct stores all needed fields
  to create an event downstream. Pre-eliminary validation is made
  to detect user errors early.
  """

  use Ecto.Schema
  alias Ecto.Changeset

  @max_url_size 2_000

  embedded_schema do
    field :remote_ip, :string
    field :user_agent, :string
    field :event_name, :string
    field :uri, :map
    field :hostname, :string
    field :referrer, :string
    field :domains, {:array, :string}
    field :hash_mode, :string
    field :pathname, :string
    field :props, :map
    field :query_params, :map

    field :timestamp, :naive_datetime
  end

  @type t() :: %__MODULE__{}

  @spec build(Plug.Conn.t(), NaiveDateTime.t()) :: {:ok, t()} | {:error, Changeset.t()}
  @doc """
  Builds and initially validates %Plausible.Ingestion.Request{} struct from %Plug.Conn{}.
  """
  def build(%Plug.Conn{} = conn, now \\ NaiveDateTime.utc_now()) do
    changeset =
      %__MODULE__{}
      |> Changeset.change()
      |> Changeset.put_change(
        :timestamp,
        NaiveDateTime.truncate(now, :second)
      )

    case parse_body(conn) do
      {:ok, request_body} ->
        changeset
        |> put_remote_ip(conn)
        |> put_uri(request_body)
        |> put_hostname()
        |> put_user_agent(conn)
        |> put_request_params(request_body)
        |> put_referrer(request_body)
        |> put_props(request_body)
        |> put_pathname()
        |> put_query_params()
        |> map_domains(request_body)
        |> Changeset.validate_required([
          :event_name,
          :hostname,
          :pathname,
          :timestamp
        ])
        |> Changeset.validate_length(:event_name, max: 120)
        |> Changeset.apply_action(nil)

      {:error, :invalid_json} ->
        {:error, Changeset.add_error(changeset, :request, "Unable to parse request body as json")}
    end
  end

  defp put_remote_ip(changeset, conn) do
    Changeset.put_change(changeset, :remote_ip, PlausibleWeb.RemoteIp.get(conn))
  end

  defp parse_body(conn) do
    case conn.body_params do
      %Plug.Conn.Unfetched{} ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)

        case Jason.decode(body) do
          {:ok, params} when is_map(params) -> {:ok, params}
          _ -> {:error, :invalid_json}
        end

      params ->
        {:ok, params}
    end
  end

  defp put_request_params(changeset, %{} = request_body) do
    Changeset.change(
      changeset,
      event_name: request_body["n"] || request_body["name"],
      hash_mode: request_body["h"] || request_body["hashMode"]
    )
  end

  defp put_referrer(changeset, %{} = request_body) do
    referrer = request_body["r"] || request_body["referrer"]

    if is_binary(referrer) do
      referrer = String.slice(referrer, 0..(@max_url_size - 1))
      Changeset.put_change(changeset, :referrer, referrer)
    else
      changeset
    end
  end

  defp put_pathname(changeset) do
    uri = Changeset.get_field(changeset, :uri)
    hash_mode = Changeset.get_field(changeset, :hash_mode)
    pathname = get_pathname(uri, hash_mode)
    Changeset.put_change(changeset, :pathname, pathname)
  end

  defp map_domains(changeset, %{} = request_body) do
    raw = request_body["d"] || request_body["domain"]
    raw = if is_binary(raw), do: String.trim(raw)

    case raw do
      "" ->
        Changeset.add_error(changeset, :domain, "can't be blank")

      raw when is_binary(raw) ->
        domains =
          raw
          |> String.split(",")
          |> Enum.map(&sanitize_hostname/1)

        Changeset.put_change(changeset, :domains, domains)

      nil ->
        from_uri = sanitize_hostname(Changeset.get_field(changeset, :uri))

        if from_uri do
          Changeset.put_change(changeset, :domains, [from_uri])
        else
          Changeset.add_error(changeset, :domain, "can't be blank")
        end
    end
  end

  @disallowed_schemes ~w(data)
  defp put_uri(changeset, %{} = request_body) do
    with url when is_binary(url) <- request_body["u"] || request_body["url"],
         url when byte_size(url) <= @max_url_size <- url,
         %URI{} = uri when uri.scheme not in @disallowed_schemes <- URI.parse(url) do
      Changeset.put_change(changeset, :uri, uri)
    else
      nil -> Changeset.add_error(changeset, :url, "is required")
      %URI{} -> Changeset.add_error(changeset, :url, "scheme is not allowed")
      _ -> Changeset.add_error(changeset, :url, "must be a valid url")
    end
  end

  defp put_hostname(changeset) do
    host =
      case Changeset.get_field(changeset, :uri) do
        %{host: host} when is_binary(host) and host != "" -> host
        _ -> "(none)"
      end

    Changeset.put_change(changeset, :hostname, sanitize_hostname(host))
  end

  defp put_props(changeset, %{} = request_body) do
    props =
      (request_body["m"] || request_body["meta"] || request_body["p"] || request_body["props"])
      |> decode_props_or_fallback()
      |> Enum.reject(fn {_k, v} -> is_nil(v) || is_list(v) || is_map(v) || v == "" end)
      |> Map.new()

    changeset
    |> Changeset.put_change(:props, props)
    |> validate_props()
  end

  defp decode_props_or_fallback(raw) do
    with raw when is_binary(raw) <- raw,
         {:ok, %{} = decoded} <- Jason.decode(raw) do
      decoded
    else
      already_a_map when is_map(already_a_map) -> already_a_map
      {:ok, _list_or_other} -> %{}
      {:error, _decode_error} -> %{}
      _any -> %{}
    end
  end

  @max_prop_key_length 300
  @max_prop_value_length 2000
  defp validate_props(changeset) do
    case Changeset.get_field(changeset, :props) do
      props ->
        Enum.reduce_while(props, changeset, fn
          {key, value}, changeset
          when byte_size(key) > @max_prop_key_length or
                 byte_size(value) > @max_prop_value_length ->
            {:halt,
             Changeset.add_error(
               changeset,
               :props,
               "keys should have at most #{@max_prop_key_length} bytes and values #{@max_prop_value_length} bytes"
             )}

          _, changeset ->
            {:cont, changeset}
        end)
    end
  end

  defp put_query_params(changeset) do
    case Changeset.get_field(changeset, :uri) do
      %{query: query} when is_binary(query) ->
        Changeset.put_change(changeset, :query_params, URI.decode_query(query))

      _any ->
        changeset
    end
  end

  defp put_user_agent(changeset, %Plug.Conn{} = conn) do
    user_agent =
      conn
      |> Plug.Conn.get_req_header("user-agent")
      |> List.first()

    Changeset.put_change(changeset, :user_agent, user_agent)
  end

  defp get_pathname(nil, _hash_mode), do: "/"

  defp get_pathname(uri, hash_mode) do
    pathname =
      (uri.path || "/")
      |> URI.decode()
      |> String.trim_trailing()

    if hash_mode == 1 && uri.fragment do
      pathname <> "#" <> URI.decode(uri.fragment)
    else
      pathname
    end
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
