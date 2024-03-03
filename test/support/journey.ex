defmodule Plausible.Test.Support.Journey do
  defmacro __using__(_) do
    quote do
      require Plausible.Test.Support.Journey
      import Plausible.Test.Support.Journey
    end
  end

  import Phoenix.ConnTest
  import Plug.Conn

  def run(site, state, journey) do
    Enum.reduce(journey, state, fn
      {:pageview, [url, opts]}, state ->
        payload = %{
          name: "pageview",
          domain: site.domain,
          url: build_url(site.domain, url, opts)
        }

        payload |> new_conn(state) |> ingest(state, Keyword.get(opts, :idle, 1))

      {:custom_event, [name, opts]}, state ->
        payload = %{name: name, domain: site.domain, url: build_url(site.domain, "/", opts)}
        payload |> new_conn(state) |> ingest(state, Keyword.get(opts, :idle, 1))
    end)

    if !state[:manual] do
      flush_buffers()
    end
  end

  defp build_url(domain, url, _opts) do
    "https://" <> Path.join(domain, url)
  end

  defp new_conn(payload, state) do
    (state.conn || build_conn(:post, "/api/events", payload))
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

  def flush_buffers do
    Plausible.Session.WriteBuffer.flush()
    Plausible.Event.WriteBuffer.flush()
  end

  defp ingest(conn, state, idle_offset) do
    now = invoke_if_function(state.now)

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
    mod = :"#{__CALLER__.module}.Journey#{:erlang.phash2(binding())}"
    __journey__(aliased(state[:manual]) || mod, site, state, block)
  end

  defp aliased({:__aliases__, _, mod}), do: Module.concat(mod)
  defp aliased(other), do: other

  defp __journey__(mod, site, state, block) do
    quote do
      defmodule unquote(mod) do
        Module.register_attribute(__MODULE__, :journey, accumulate: true)
        @site unquote(site)
        @initial_state default(Enum.into(unquote(state), %{}))

        unquote(block)

        def run(overrides \\ %{}) do
          Plausible.Test.Support.Journey.run(
            @site,
            Map.merge(@initial_state, overrides),
            Enum.reverse(@journey)
          )
        end

        def flush() do
          Plausible.Test.Support.Journey.flush_buffers()
        end
      end

      if is_nil(unquote(state)[:manual]) do
        unquote(mod).run()
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
