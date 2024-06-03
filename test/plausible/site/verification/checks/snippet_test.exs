defmodule Plausible.Verification.Checks.SnippetTest do
  use Plausible.DataCase, async: true

  alias Plausible.Verification.State

  @check Plausible.Verification.Checks.Snippet

  test "skips when there's no document" do
    state = %State{}
    assert ^state = @check.perform(state)
  end

  @well_placed """
  <head>
  <script defer data-domain="example.com" event-author="Me" src="http://localhost:8000/js/script.js"></script>
  </head>
  """

  test "figures out well placed snippet" do
    state =
      @well_placed
      |> new_state()
      |> @check.perform()

    assert state.diagnostics.snippets_found_in_head == 1
    assert state.diagnostics.snippets_found_in_body == 0
    refute state.diagnostics.data_domain_mismatch?
    refute state.diagnostics.snippet_unknown_attributes?
    refute state.diagnostics.proxy_likely?
    refute state.diagnostics.manual_script_extension?
  end

  @multi_domain """
  <head>
  <script defer data-domain="example.org,example.com,example.net" src="http://localhost:8000/js/script.js"></script>
  </head>
  """

  test "figures out well placed snippet in a multi-domain setup" do
    state =
      @multi_domain
      |> new_state()
      |> @check.perform()

    assert state.diagnostics.snippets_found_in_head == 1
    assert state.diagnostics.snippets_found_in_body == 0
    refute state.diagnostics.data_domain_mismatch?
    refute state.diagnostics.snippet_unknown_attributes?
    refute state.diagnostics.proxy_likely?
    refute state.diagnostics.manual_script_extension?
  end

  @crazy """
  <head>
  <script defer data-domain="example.com" src="http://localhost:8000/js/script.js"></script>
  <script defer data-domain="example.com" src="http://localhost:8000/js/script.js"></script>
  </head>
  <body>
  <script defer data-domain="example.com" src="http://localhost:8000/js/script.js"></script>
  <script defer data-domain="example.com" src="http://localhost:8000/js/script.js"></script>
  <script defer data-domain="example.com" src="http://localhost:8000/js/script.js"></script>
  </body>
  """
  test "counts snippets" do
    state =
      @crazy
      |> new_state()
      |> @check.perform()

    assert state.diagnostics.snippets_found_in_head == 2
    assert state.diagnostics.snippets_found_in_body == 3
    refute state.diagnostics.manual_script_extension?
  end

  test "figures out data-domain mismatch" do
    state =
      @well_placed
      |> new_state(data_domain: "example.typo")
      |> @check.perform()

    assert state.diagnostics.snippets_found_in_head == 1
    assert state.diagnostics.snippets_found_in_body == 0
    assert state.diagnostics.data_domain_mismatch?
    refute state.diagnostics.snippet_unknown_attributes?
    refute state.diagnostics.proxy_likely?
    refute state.diagnostics.manual_script_extension?
  end

  @proxy_likely """
  <head>
  <script defer data-domain="example.com" src="http://my-domain.example.com/js/script.js"></script>
  </head>
  """

  test "figures out proxy likely" do
    state =
      @proxy_likely
      |> new_state()
      |> @check.perform()

    assert state.diagnostics.snippets_found_in_head == 1
    assert state.diagnostics.snippets_found_in_body == 0
    refute state.diagnostics.data_domain_mismatch?
    refute state.diagnostics.snippet_unknown_attributes?
    assert state.diagnostics.proxy_likely?
    refute state.diagnostics.manual_script_extension?
  end

  @manual_extension """
  <head>
  <script defer data-domain="example.com" event-author="Me" src="http://localhost:8000/js/script.manual.js"></script>
  </head>
  """

  test "figures out manual script extension" do
    state =
      @manual_extension
      |> new_state()
      |> @check.perform()

    assert state.diagnostics.manual_script_extension?
  end

  @unknown_attributes """
  <head>
  <script defer data-api="some" data-include="some" data-exclude="some" weird="one" data-domain="example.com" src="http://my-domain.example.com/js/script.js"></script>
  </head>
  """

  @valid_attributes """
  <head>
  <script defer type="text/javascript" data-api="some" data-include="some" data-exclude="some" data-domain="example.com" src="http://my-domain.example.com/js/script.js"></script>
  </head>
  """

  test "figures out unknown attributes" do
    state =
      @valid_attributes
      |> new_state()
      |> @check.perform()

    refute state.diagnostics.snippet_unknown_attributes?

    state =
      @unknown_attributes
      |> new_state()
      |> @check.perform()

    assert state.diagnostics.snippet_unknown_attributes?
  end

  defp new_state(html, opts \\ []) do
    doc = Floki.parse_document!(html)

    opts =
      [data_domain: "example.com"]
      |> Keyword.merge(opts)

    State
    |> struct!(opts)
    |> State.assign(document: doc)
  end
end
