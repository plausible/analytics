defmodule Plausible.Test.Support.Journey do
  @moduledoc "TODO"

  defmacro __using__(_) do
    quote do
      require Plausible.Test.Support.Journey
      import Plausible.Test.Support.Journey

      Module.register_attribute(__MODULE__, :journey_index, accumulate: false)
      Module.put_attribute(__MODULE__, :journey_index, 0)
    end
  end

  import Plug.Adapters.Test.Conn, only: [conn: 4]
  import Plug.Conn

  def run(site, state, journey) do
    conn = new_conn(state)
    # credo:disable-for-this-file Credo.Check.Warning.UnusedEnumOperation
    Enum.reduce(journey, state, fn
      {:pageview, [url, opts]}, state ->
        payload =
          %{
            name: "pageview",
            domain: site.domain,
            url: build_url(site, url, opts)
          }
          |> add_common_body_params(opts)

        conn
        |> Plug.Adapters.Test.Conn.conn(:post, "/api/events", payload)
        |> ingest(state, invoke_if_function(Keyword.get(opts, :idle, 1), state.now))

      {:custom_event, [name, opts]}, state ->
        payload =
          %{name: name, domain: site.domain, url: build_url(site, "/", opts)}
          |> add_common_body_params(opts)

        payload =
          if opts[:props] do
            Map.put(payload, :props, opts[:props])
          else
            payload
          end

        conn
        |> conn(:post, "/api/events", payload)
        |> ingest(state, invoke_if_function(Keyword.get(opts, :idle, 1), state.now))
    end)

    if !state[:manual] do
      flush_buffers()
    end
  end

  defp add_common_body_params(payload, params) do
    params =
      params
      |> Enum.into(%{})
      |> Map.take(~w[referrer]a)

    if Enum.empty?(params) do
      payload
    else
      Map.merge(payload, params)
    end
  end

  def build_url(site, path, params) do
    if params[:url] do
      params[:url]
    else
      site_domain = site.domain |> URI.encode_www_form()

      query_string =
        params
        |> Enum.into(%{})
        |> Map.take(~w[utm_source utm_medium utm_campaign utm_term utm_content]a)
        |> URI.encode_query()

      uri = URI.new!("https://" <> Path.join(site_domain, path))
      uri = %{uri | query: query_string}
      to_string(uri)
    end
  end

  defp new_conn(state) do
    (state.conn || %Plug.Conn{})
    |> put_req_header("content-type", "application/json")
    |> maybe_add_header("x-forwarded-for", invoke_if_function(state.ip))
    |> maybe_add_header("user-agent", invoke_if_function(state.user_agent))
  end

  defp maybe_add_header(conn, _header, nil) do
    conn
  end

  defp maybe_add_header(conn, header, value) do
    put_req_header(conn, header, value)
  end

  defp invoke_if_function(f) when is_function(f, 0), do: f.()
  defp invoke_if_function(value), do: value

  defp invoke_if_function(f, arg) when is_function(f, 1), do: f.(arg)
  defp invoke_if_function(value, _), do: value

  def flush_buffers do
    Plausible.Session.WriteBuffer.flush()
    Plausible.Event.WriteBuffer.flush()
  end

  defp ingest(conn, state, idle) do
    now = invoke_if_function(state.now)

    idle_offset =
      case idle do
        n when is_integer(n) ->
          n

        %NaiveDateTime{} = ndt ->
          NaiveDateTime.diff(ndt, now, :second)
      end

    {:ok, request} =
      Plausible.Ingestion.Request.build(conn, now)

    Plausible.Ingestion.Event.build_and_buffer(request)

    new_now = NaiveDateTime.add(now, idle_offset, :second)
    Map.put(state, :now, new_now)
  end

  defmacro default(state) do
    h1 = :erlang.phash2(__CALLER__.module, 256)
    h2 = :erlang.phash2(__CALLER__.line, 256)

    default_ip = "#{h1}.#{h2}.#{h1}.#{h2}"
    default_user_agent = "JourneyBrowser #{__CALLER__.module}/#{__CALLER__.line}"

    quote do
      unquote(state)
      |> Map.update(:now, &NaiveDateTime.utc_now/0, & &1)
      |> Map.update(:conn, nil, & &1)
      |> Map.update(:ip, unquote(default_ip), & &1)
      |> Map.update(:user_agent, unquote(default_user_agent), & &1)
    end
  end

  defmacro journey(site, state \\ [], do: block) do
    idx = Module.get_attribute(__CALLER__.module, :journey_index)
    idx = idx + 1

    Module.put_attribute(__CALLER__.module, :journey_index, idx)
    mod = :"#{__CALLER__.module}.Journey#{idx}"

    __journey__(mod, site, state, block, aliased(state[:manual]))
  end

  defp aliased({:__aliases__, _, mod}), do: Module.concat(mod)
  defp aliased(other), do: other

  defmacro module_name(mod, site, state, nil) do
    :"#{mod}_#{:erlang.phash2({site, state})}"
  end

  defmacro module_name(_, _, _, manual) do
    manual
  end

  defp __journey__(mod, site, state, block, mod_override) do
    quote do
      defmodule :"#{module_name(unquote(mod), unquote(site), unquote(state), unquote(mod_override))}" do
        Module.register_attribute(__MODULE__, :journey, accumulate: true)
        @site unquote(site)
        @initial_state default(Enum.into(unquote(state), %{}))

        unquote(block)

        def run() do
          Plausible.Test.Support.Journey.run(
            @site,
            @initial_state,
            Enum.reverse(@journey)
          )
        end

        def flush() do
          Plausible.Test.Support.Journey.flush_buffers()
        end

        def run_many(n) do
          1..n
          |> Task.async_stream(fn _ -> run() end)
          |> Stream.run()

          flush()
        end
      end

      if is_nil(unquote(state)[:manual]) do
        :"#{module_name(unquote(mod), unquote(site), unquote(state), unquote(mod_override))}".run()
      end
    end
  end

  defmacro pageview(url, opts \\ []) do
    quote do: store(:pageview, [unquote(url), unquote(opts)])
  end

  defmacro custom_event(name, opts \\ []) do
    quote do: store(:custom_event, [unquote(name), unquote(opts)])
  end

  defmacro store(op, args) do
    quote do
      Module.put_attribute(__MODULE__, :journey, {unquote(op), unquote(args)})
    end
  end
end
