defmodule PlausibleWeb.Live.InstallationV2 do
  @moduledoc """
  User assistance module around Plausible installation instructions/onboarding
  """
  use PlausibleWeb, :live_view

  def mount(
        %{"domain" => domain} = params,
        _session,
        socket
      ) do
    site =
      Plausible.Sites.get_for_user!(socket.assigns.current_user, domain, [
        :owner,
        :admin,
        :editor,
        :super_admin,
        :viewer
      ])

    {:ok, assign(socket, site: site)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1>Installation V2 for {@site.domain}</h1>
    </div>
    """
  end
end
