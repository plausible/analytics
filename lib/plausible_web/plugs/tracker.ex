defmodule PlausibleWeb.Tracker do
  import Plug.Conn
  use Agent

  @templates [
    "plausible.js",
    "plausible.exclusions.js",
    "plausible.hash.exclusions.js",
    "plausible.hash.outbound-links.js",
    "plausible.hash.exclusions.outbound-links.js",
    "plausible.exclusions.outbound-links.js",
    "p.js"
  ]
  @aliases %{
    "plausible.js" => ["analytics.js"],
    "plausible.hash.outbound-links.js" => ["plausible.outbound-links.hash.js"],
    "plausible.hash.exclusions.js" => ["plausible.exclusions.hash.js"],
    "plausible.exclusions.outbound-links.js" => ["plausible.outbound-links.exclusions.js"],
    "plausible.hash.exclusions.outbound-links.js" => [
      "plausible.exclusions.hash.outbound-links.js",
      "plausible.exclusions.outbound-links.hash.js",
      "plausible.hash.outbound-links.exclusions.js",
      "plausible.outbound-links.hash.exclusions.js",
      "plausible.outbound-links.exclusions.hash.js"
    ]
  }

  #  1 hour
  @max_age 3600

  def init(_) do
    templates =
      Enum.reduce(@templates, %{}, fn template_filename, rendered_templates ->
        rendered = EEx.compile_file("priv/tracker/js/" <> template_filename)

        aliases = Map.get(@aliases, template_filename, [])

        [template_filename | aliases]
        |> Enum.map(fn filename -> {"/js/" <> filename, rendered} end)
        |> Enum.into(%{})
        |> Map.merge(rendered_templates)
      end)

    [templates: templates]
  end

  def call(conn, templates: templates) do
    case templates[conn.request_path] do
      nil ->
        conn

      found ->
        {js, _} = Code.eval_quoted(found, base_url: PlausibleWeb.Endpoint.url())
        send_js(conn, js)
    end
  end

  defp send_js(conn, file) do
    conn
    |> put_resp_header("cache-control", "max-age=#{@max_age},public")
    |> put_resp_header("content-type", "application/javascript")
    |> put_resp_header("cross-origin-resource-policy", "cross-origin")
    |> send_resp(200, file)
    |> halt()
  end
end
