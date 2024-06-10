defmodule Plausible.Verification.Checks.FetchBodyTest do
  use Plausible.DataCase, async: true

  import Plug.Conn

  @check Plausible.Verification.Checks.FetchBody

  @normal_body """
  <html>
  <head>
  <script defer data-domain="example.com" src="http://localhost:8000/js/script.js"></script>
  </head>
  <body>Hello</body>
  </html>
  """

  setup do
    {:ok,
     state: %Plausible.Verification.State{
       url: "https://example.com"
     }}
  end

  test "extracts document", %{state: state} do
    stub()
    state = @check.perform(state)

    assert state.assigns.raw_body == @normal_body
    assert state.assigns.document == Floki.parse_document!(@normal_body)
    assert state.assigns.headers["content-type"] == ["text/html; charset=utf-8"]

    assert state.diagnostics.body_fetched?
  end

  test "does extract on non-2xx", %{state: state} do
    stub(400)
    state = @check.perform(state)
    assert state.diagnostics.body_fetched?
  end

  test "doesn't extract non-HTML", %{state: state} do
    stub(200, @normal_body, "text/plain")
    state = @check.perform(state)

    assert state.assigns == %{final_domain: "example.com"}

    refute state.diagnostics.body_fetched?
  end

  defp stub(f) when is_function(f, 1) do
    Req.Test.stub(@check, f)
  end

  defp stub(status \\ 200, body \\ @normal_body, content_type \\ "text/html") do
    stub(fn conn ->
      conn
      |> put_resp_content_type(content_type)
      |> send_resp(status, body)
    end)
  end
end
