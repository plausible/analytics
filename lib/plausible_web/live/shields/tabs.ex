defmodule PlausibleWeb.Live.Shields.Tabs do
  @moduledoc """
  Currently only a placeholder module. Once more shields
  are implemented it will display tabs with counters,
  linking to their respective live views.
  """
  use PlausibleWeb, :live_view
  use Phoenix.HTML

  alias Plausible.Shields
  alias Plausible.Sites

  def mount(
        _params,
        %{
          "remote_ip" => remote_ip,
          "domain" => domain,
          "current_user_id" => user_id
        },
        socket
      ) do
    socket =
      socket
      |> assign_new(:site, fn ->
        Sites.get_for_user!(user_id, domain, [:owner, :admin, :super_admin])
      end)
      |> assign_new(:ip_rules_count, fn %{site: site} ->
        Shields.count_ip_rules(site)
      end)
      |> assign_new(:current_user, fn ->
        Plausible.Repo.get(Plausible.Auth.User, user_id)
      end)
      |> assign_new(:remote_ip, fn -> remote_ip end)
      |> assign(:current_tab, :ip_rules)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <%= live_render(@socket, PlausibleWeb.Live.Shields.IPRules,
        id: "ip-rules",
        session: %{
          "domain" => @site.domain,
          "remote_ip" => @remote_ip,
          "flash" => @flash
        }
      ) %>
    </div>
    """
  end
end
