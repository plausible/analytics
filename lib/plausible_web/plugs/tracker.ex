defmodule PlausibleWeb.Tracker do
  import Plug.Conn
  use Agent

  base_variants = [
    "hash",
    "outbound-links",
    "exclusions",
    "compat",
    "local",
    "manual",
    "file-downloads",
    "pageview-props",
    "tagged-events",
    "revenue",
    "pageleave"
  ]

  # Generates Power Set of all variants
  variants =
    1..Enum.count(base_variants)
    |> Enum.map(fn x ->
      Combination.combine(base_variants, x)
      |> Enum.map(fn y -> Enum.sort(y) |> Enum.join(".") end)
    end)
    |> List.flatten()

  @base_filenames ["plausible", "script", "analytics"]
  @files_available ["plausible.js", "p.js"] ++ Enum.map(variants, fn v -> "plausible.#{v}.js" end)

  def init(opts) do
    Keyword.merge(opts, files_available: MapSet.new(@files_available))
  end

  def call(conn, files_available: files_available) do
    filename =
      case conn.request_path do
        "/js/p.js" ->
          "p.js"

        "/js/" <> requested_filename ->
          sorted_script_variant(requested_filename)

        _ ->
          nil
      end

    if filename && MapSet.member?(files_available, filename) do
      location = Application.app_dir(:plausible, "priv/tracker/js/" <> filename)

      conn
      |> put_resp_header("content-type", "application/javascript")
      |> put_resp_header("x-content-type-options", "nosniff")
      |> put_resp_header("cross-origin-resource-policy", "cross-origin")
      |> put_resp_header("access-control-allow-origin", "*")
      |> put_resp_header("cache-control", "public, max-age=86400, must-revalidate")
      |> send_file(200, location)
      |> halt()
    else
      conn
    end
  end

  # Variants which do not factor into output
  @ignore_variants ["js", "pageleave"]

  defp sorted_script_variant(requested_filename) do
    case String.split(requested_filename, ".") do
      [base_filename | rest] when base_filename in @base_filenames ->
        sorted_variants =
          rest
          |> Enum.reject(&(&1 in @ignore_variants))
          |> Enum.sort()

        Enum.join(["plausible"] ++ sorted_variants ++ ["js"], ".")

      _ ->
        nil
    end
  end
end
