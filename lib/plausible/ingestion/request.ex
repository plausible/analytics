defmodule Plausible.Ecto.EventName do
  @moduledoc """
    Custom type for event name. Accepts Strings and Integers and stores them as String. Returns
    cast error if any other type is provided. Accepting integers is important for 404 tracking.
  """

  use Ecto.Type
  def type, do: :string

  def cast(val) when is_binary(val), do: {:ok, val}
  def cast(val) when is_integer(val), do: {:ok, Integer.to_string(val)}

  def cast(_), do: :error
  def load(val), do: {:ok, val}
  def dump(val), do: {:ok, val}
end

defmodule Plausible.Ingestion.Request do
  @moduledoc """
  The %Plausible.Ingestion.Request{} struct stores all needed fields
  to create an event downstream. Pre-eliminary validation is made
  to detect user errors early.
  """

  use Ecto.Schema
  use Plausible
  alias Ecto.Changeset

  @max_url_size 2_000
  @missing_scroll_depth 255
  @missing_engagement_time 0

  # :KLUDGE: Old version of tracker script sent huge values for engagement time. Ignore
  # these while users might still have the old script cached.
  @too_large_engagement_time :timer.hours(30 * 24)

  @blank_engagement_error_message "engagement event requires a valid integer value for at least one of 'sd' or 'e' fields"

  def too_large_engagement_time(), do: @too_large_engagement_time
  def blank_engagement_error_message(), do: @blank_engagement_error_message

  @primary_key false
  embedded_schema do
    field :remote_ip, :string
    field :user_agent, :string
    field :event_name, Plausible.Ecto.EventName
    field :uri, :map
    field :hostname, :string
    field :referrer, :string
    field :domains, {:array, :string}
    field :ip_classification, :string
    field :hash_mode, :integer
    field :pathname, :string
    field :props, :map
    field :scroll_depth, :integer
    field :engagement_time, :integer
    field :tracker_script_version, :integer, default: 0
    field :interactive?, :boolean, default: true

    on_ee do
      field :revenue_source, :map
    end

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
        |> put_ip_classification(conn)
        |> put_remote_ip(conn)
        |> put_uri(request_body)
        |> put_hostname()
        |> put_user_agent(conn)
        |> put_request_params(request_body)
        |> put_referrer(request_body)
        |> put_pathname()
        |> put_props(request_body)
        |> put_engagement_fields(request_body)
        |> put_query_params()
        |> put_revenue_source(request_body)
        |> put_interactive(request_body)
        |> put_tracker_script_version(request_body)
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

  on_ee do
    defp put_revenue_source(changeset, request_body) do
      Plausible.Ingestion.Request.Revenue.put_revenue_source(changeset, request_body)
    end
  else
    defp put_revenue_source(changeset, _request_body), do: changeset
  end

  defp put_remote_ip(changeset, conn) do
    Changeset.put_change(changeset, :remote_ip, PlausibleWeb.RemoteIP.get(conn))
  end

  defp parse_body(conn) do
    case conn.body_params do
      %Plug.Conn.Unfetched{} ->
        with max_length <- conn.assigns[:read_body_limit] || 1_000_000,
             {:ok, body, _conn} <-
               Plug.Conn.read_body(conn, length: max_length, read_length: max_length),
             {:ok, params} when is_map(params) <- Jason.decode(body) do
          {:ok, params}
        else
          _ -> {:error, :invalid_json}
        end

      params ->
        {:ok, params}
    end
  end

  defp put_request_params(changeset, %{} = request_body) do
    Changeset.cast(
      changeset,
      %{
        event_name: request_body["n"] || request_body["name"],
        hash_mode: request_body["h"] || request_body["hashMode"]
      },
      [:event_name, :hash_mode]
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

  defp maybe_set_props_path_to_pathname(props_in_request, changeset) do
    if Plausible.Goals.SystemGoals.should_sync_props_path_with_pathname?(
         Changeset.get_field(changeset, :event_name),
         props_in_request
       ) do
      # "path" props is added to the head of the props enum to avoid it being cut off
      [{"path", Changeset.get_field(changeset, :pathname)}] ++ props_in_request
    else
      props_in_request
    end
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
        %{host: host} when is_binary(host) and host != "" -> sanitize_hostname(host)
        _ -> "(none)"
      end

    Changeset.put_change(changeset, :hostname, host)
  end

  @max_props 30
  defp put_props(changeset, %{} = request_body) do
    props =
      (request_body["m"] || request_body["meta"] || request_body["p"] || request_body["props"])
      |> Plausible.Helpers.JSON.decode_or_fallback()
      |> Enum.reduce([], &filter_bad_props/2)
      |> maybe_set_props_path_to_pathname(changeset)
      |> Enum.take(@max_props)
      |> Map.new()

    changeset
    |> Changeset.put_change(:props, props)
    |> validate_props()
  end

  defp put_interactive(changeset, %{} = request_body) do
    case request_body["i"] || request_body["interactive"] do
      interactive? when is_boolean(interactive?) ->
        Changeset.put_change(changeset, :interactive?, interactive?)

      _ ->
        changeset
    end
  end

  defp filter_bad_props({k, v}, acc) do
    cond do
      Enum.any?([k, v], &(is_list(&1) or is_map(&1))) -> acc
      Enum.any?([k, v], &(String.trim_leading(to_string(&1)) == "")) -> acc
      true -> [{to_string(k), to_string(v)} | acc]
    end
  end

  @max_prop_key_length Plausible.Props.max_prop_key_length()
  @max_prop_value_length Plausible.Props.max_prop_value_length()
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

  defp put_engagement_fields(changeset, %{} = request_body) do
    if Changeset.get_field(changeset, :event_name) == "engagement" do
      scroll_depth = parse_scroll_depth(request_body["sd"])
      engagement_time = parse_engagement_time(request_body["e"])

      case {scroll_depth, engagement_time} do
        {@missing_scroll_depth, @missing_engagement_time} ->
          changeset
          |> Changeset.add_error(
            :event_name,
            "engagement event requires a valid integer value for at least one of 'sd' or 'e' fields"
          )

        _ ->
          changeset
          |> Changeset.put_change(:scroll_depth, scroll_depth)
          |> Changeset.put_change(:engagement_time, engagement_time)
      end
    else
      changeset
    end
  end

  defp put_tracker_script_version(changeset, %{} = request_body) do
    case request_body["v"] do
      version when is_integer(version) ->
        Changeset.put_change(changeset, :tracker_script_version, version)

      _ ->
        changeset
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

  defp put_ip_classification(changeset, %Plug.Conn{} = conn) do
    value =
      conn
      |> Plug.Conn.get_req_header("x-plausible-ip-type")
      |> List.first()

    Changeset.put_change(changeset, :ip_classification, value)
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

  defp parse_scroll_depth(sd) when is_binary(sd) do
    case Integer.parse(sd) do
      {sd_int, ""} -> parse_scroll_depth(sd_int)
      _ -> @missing_scroll_depth
    end
  end

  defp parse_scroll_depth(sd) when is_integer(sd) and sd >= 0 and sd <= 100, do: sd
  defp parse_scroll_depth(sd) when is_integer(sd) and sd > 100, do: 100
  defp parse_scroll_depth(_), do: @missing_scroll_depth

  defp parse_engagement_time(et) when is_binary(et) do
    case Integer.parse(et) do
      {et_int, ""} -> parse_engagement_time(et_int)
      _ -> @missing_engagement_time
    end
  end

  defp parse_engagement_time(et)
       when is_integer(et) and et >= 0 and et < @too_large_engagement_time,
       do: et

  defp parse_engagement_time(_), do: @missing_engagement_time
end

defimpl Jason.Encoder, for: URI do
  def encode(uri, _opts), do: [?", URI.to_string(uri), ?"]
end

defimpl Jason.Encoder, for: Plausible.Ingestion.Request do
  @fields Plausible.Ingestion.Request.__schema__(:fields)
  def encode(request, opts) do
    request
    |> Map.take(@fields)
    |> Jason.Encode.map(opts)
  end
end
