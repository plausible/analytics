defmodule PlausibleWeb.TrackerPlug do
  @moduledoc """
  Plug to serve the Plausible tracker script.
  """

  import Plug.Conn
  import Ecto.Query
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
  legacy_variants =
    1..Enum.count(base_variants)
    |> Enum.map(fn x ->
      Combination.combine(base_variants, x)
      |> Enum.map(fn y -> Enum.sort(y) |> Enum.join(".") end)
    end)
    |> List.flatten()

  @base_legacy_filenames ["plausible", "script", "analytics"]
  @files_available ["plausible.js", "p.js"] ++
                     Enum.map(legacy_variants, fn v -> "plausible.#{v}.js" end)

  def init(opts) do
    Keyword.merge(opts, files_available: MapSet.new(@files_available))
  end

  def call(conn, files_available: files_available) do
    case conn.request_path do
      "/js/s-" <> path ->
        if String.ends_with?(path, ".js") do
          tag = String.replace_trailing(path, ".js", "")
          request_tracker_script(tag, conn)
        else
          conn
        end

      "/js/p.js" ->
        legacy_request_file("p.js", files_available, conn)

      "/js/" <> requested_filename ->
        sorted_script_variant(requested_filename) |> legacy_request_file(files_available, conn)

      _ ->
        conn
    end
  end

  def telemetry_event(name), do: [:plausible, :tracker_script, :request, name]

  defp request_tracker_script(tag, conn) do
    tracker_script_configuration =
      Plausible.Repo.one(
        from s in Plausible.Site.TrackerScriptConfiguration, where: s.id == ^tag, preload: [:site]
      )

    if tracker_script_configuration do
      script_tag = PlausibleWeb.Tracker.plausible_main_script_tag(tracker_script_configuration)

      :telemetry.execute(
        telemetry_event(:v2),
        %{},
        %{status: 200}
      )

      conn
      |> put_resp_header("content-type", "application/javascript")
      |> put_resp_header("x-content-type-options", "nosniff")
      |> put_resp_header("cross-origin-resource-policy", "cross-origin")
      |> put_resp_header("access-control-allow-origin", "*")
      |> put_resp_header("cache-control", "public, max-age=60, no-transform")
      # CDN-Tag is used by BunnyCDN to tag cached resources. This allows us to purge
      # specific tracker scripts from the CDN cache.
      |> put_resp_header("cdn-tag", "tracker_script::#{tracker_script_configuration.id}")
      |> send_resp(200, script_tag)
      |> halt()
    else
      :telemetry.execute(
        telemetry_event(:v2),
        %{},
        %{status: 404}
      )

      conn
      |> send_resp(404, "Not found")
      |> halt()
    end
  end

  defp legacy_request_file(filename, files_available, conn) do
    if filename && MapSet.member?(files_available, filename) do
      location = Application.app_dir(:plausible, "priv/tracker/js/" <> filename)

      :telemetry.execute(
        telemetry_event(:legacy),
        %{},
        %{status: 200}
      )

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
      [base_filename | rest] when base_filename in @base_legacy_filenames ->
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
