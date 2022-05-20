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
    "dimensions"
  ]

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

  @script_aliases ["plausible.js", "script.js", "analytics.js"]
  @base_filenames ["plausible", "script"]
  @files_available files_available

  def init(_) do
    [files: @files_available]
  end

  def call(conn, files: files) do
    filename = case conn.request_path do
      "/js/p.js" ->
        "p.js"

      "/js/" <> script_alias when script_alias in @script_aliases ->
        "plausible.js"

      "/js/" <> requested_filename ->
        sorted_script_variant(requested_filename)

      _ -> nil
    end

    case filename && Enum.find(files, &(&1 == filename)) do
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

  defp sorted_script_variant(requested_filename) do
    case String.split(requested_filename, ".") do
      [base_filename | rest] when base_filename in @base_filenames ->
        sorted_variants =
          rest
          |> List.delete("js")
          |> Enum.sort()
          |> Enum.join(".")

        "plausible.#{sorted_variants}.js"

      _ -> nil
    end
  end
end
