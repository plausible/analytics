defmodule PlausibleWeb.Live.SentryContextTest do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  defmodule SampleLV do
    use PlausibleWeb, :live_view

    def mount(_params, %{"test" => test_pid}, socket) do
      socket = assign(socket, test_pid: test_pid)
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
      ok computer
      """
    end

    def handle_event("get_sentry_context", _params, socket) do
      context = Sentry.Context.get_all()
      send(socket.assigns.test_pid, {:context, context})
      {:noreply, socket}
    end
  end

  describe "sentry context" do
    test "basic shape", %{conn: conn} do
      context_hook(conn)
      assert_receive {:context, context}

      assert %{
               extra: %{},
               request: %{
                 env: %{
                   "REMOTE_ADDR" => "127.0.0.1",
                   "REMOTE_PORT" => port,
                   "SEVER_NAME" => "www.example.com"
                 },
                 url: :not_mounted_at_router
               },
               user: %{},
               tags: %{},
               breadcrumbs: []
             } = context

      assert is_integer(port)
    end

    test "user-agent is included", %{conn: conn} do
      conn
      |> put_req_header("user-agent", "Firefox")
      |> context_hook()

      assert_receive {:context, context}
      assert context.request.headers["User-Agent"] == "Firefox"
    end
  end

  describe "sentry context with logged in user" do
    setup [:create_user, :log_in]

    test "user_id is included", %{conn: conn, user: user} do
      context_hook(conn)

      assert_receive {:context, context}
      assert context.user.id == user.id
    end
  end

  defp context_hook(conn, extra_session \\ %{}) do
    lv = get_liveview(conn, extra_session)
    assert render(lv) =~ "ok computer"
    render_hook(lv, :get_sentry_context, %{})
  end

  defp get_liveview(conn, extra_session) do
    {:ok, lv, _html} =
      live_isolated(conn, SampleLV, session: Map.merge(%{"test" => self()}, extra_session))

    lv
  end
end
