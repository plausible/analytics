defmodule PlausibleWeb.Tracker do
  import Plug.Conn
  use Agent

  base_variants = ["hash", "outbound-links", "exclusions"]

  # Generates Power Set of all variants
  variants =
    1..Enum.count(base_variants)
    |> Enum.map(fn x ->
      Combination.combine(base_variants, x)
      |> Enum.map(fn y -> Enum.sort(y) |> Enum.join(".") end)
    end)
    |> List.flatten()

  # Formats power set into filenames
  files_available =
    ["plausible.js", "p.js"] ++ Enum.map(variants, fn v -> "plausible.#{v}.js" end)

  # Computes permutations for every power set elements, formats them as alias filenames
  aliases_available =
    Enum.map(variants, fn x ->
      variants =
        String.split(x, ".")
        |> Combination.permutate()
        |> Enum.map(fn p -> Enum.join(p, ".") end)
        |> Enum.filter(fn permutation -> permutation != x end)
        |> Enum.map(fn v -> "plausible.#{v}.js" end)

      if Enum.count(variants) > 0 do
        {"plausible.#{x}.js", variants}
      end
    end)
    |> Enum.reject(fn x -> x == nil end)
    |> Enum.into(%{})
    |> Map.put("plausible.js", ["analytics.js"])

  @templates files_available
  @aliases aliases_available

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
