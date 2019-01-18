defmodule Mix.Tasks.BackfillDerivedData do
  use Mix.Task
  use Plausible.Repo

  def run(_) do
    Application.ensure_all_started(:plausible)

    for pageview <- Repo.all(Plausible.Pageview) do
      pageview = if pageview.user_agent do
        ua = UAInspector.Parser.parse_client(pageview.user_agent)
        Ecto.Changeset.change(pageview, %{
          device_type: device_type(ua),
          operating_system: os_name(ua),
          browser: browser_name(ua)
        })
      else
        pageview
      end

      pageview = if pageview.data.referrer && !String.contains?(pageview.data.referrer, pageview.data.hostname) do
        ref = RefInspector.parse(pageview.data.referrer)
        Ecto.Changeset.change(pageview, %{
          referrer_source: referrer_source(ref)
        })
      else
        pageview
      end

      pageview = Ecto.Changeset.change(pageview, %{screen_size: Plausible.Pageview.screen_string(pageview.data)})
      Repo.update!(pageview)
    end
  end

  defp browser_name(ua) do
    case ua.client do
      %UAInspector.Result.Client{name: "Mobile Safari"} -> "Safari"
      %UAInspector.Result.Client{name: "Chrome Mobile"} -> "Chrome"
      %UAInspector.Result.Client{name: "Chrome Mobile iOS"} -> "Chrome"
      %UAInspector.Result.Client{type: "mobile app"} -> "Mobile App"
      :unknown -> "Unknown"
      client -> client.name
    end
  end

  defp os_name(ua) do
    case ua.os do
      :unknown -> "Unknown"
      os -> os.name
    end
  end

  defp device_type(ua) do
    case ua.device do
      :unknown -> "Unknown"
      device -> String.capitalize(device.type)
    end
  end

  defp referrer_source(ref) do
    case ref.source do
      :unknown -> "Unknown"
      source -> source
    end
  end
end
