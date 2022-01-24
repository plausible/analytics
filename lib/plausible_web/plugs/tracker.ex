defmodule PlausibleWeb.Tracker do
  import Plug.Conn
  use Agent

  base_variants = ["hash", "outbound-links", "exclusions", "compat", "local", "manual"]
  base_filenames = ["plausible", "script"]

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
        |> Enum.map(fn v -> Enum.map(base_filenames, fn filename -> "#{filename}.#{v}.js" end) end)
        |> List.flatten()

      if Enum.count(variants) > 0 do
        {"plausible.#{x}.js", variants}
      end
    end)
    |> Enum.reject(fn x -> x == nil end)
    |> Enum.into(%{})
    |> Map.put("plausible.js", ["analytics.js", "script.js"])

  @templates files_available
  @aliases aliases_available

  def init(_) do
    all_files =
      Enum.reduce(@templates, %{}, fn template_filename, all_files ->
        aliases = Map.get(@aliases, template_filename, [])

        [template_filename | aliases]
        |> Enum.map(fn filename -> {"/js/" <> filename, template_filename} end)
        |> Enum.into(%{})
        |> Map.merge(all_files)
      end)

    [files: all_files]
  end

  def call(conn, files: files) do
    case files[conn.request_path] do
      nil ->
        conn

      found ->
        location = Application.app_dir(:plausible, "priv/tracker/js/" <> found)

        conn
        |> put_resp_header("content-type", "application/javascript")
        |> put_resp_header("x-content-type-options", "nosniff")
        |> put_resp_header("cross-origin-resource-policy", "cross-origin")
        |> put_resp_header("access-control-allow-origin", "*")
        |> put_resp_header("cache-control", "public, max-age=86400, must-revalidate")
        |> send_file(200, location)
        |> halt()
    end
  end
end
