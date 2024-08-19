defmodule PlausibleWeb.Live.Shields.Countries do
  @moduledoc """
  LiveView for IP Addresses Shield
  """
  use PlausibleWeb, :live_view
  use Phoenix.HTML

  alias Plausible.Shields
  alias Plausible.Sites
  alias PlausibleWeb.UserAuth

  def mount(
        _params,
        %{"domain" => domain} = session,
        socket
      ) do
    socket =
      socket
      |> assign_new(:user_session, fn ->
        {:ok, user_session} = UserAuth.get_user_session(session)
        user_session
      end)
      |> assign_new(:site, fn %{user_session: user_session} ->
        Sites.get_for_user!(user_session.user_id, domain, [:owner, :admin, :super_admin])
      end)
      |> assign_new(:country_rules_count, fn %{site: site} ->
        Shields.count_country_rules(site)
      end)
      |> assign_new(:current_user, fn %{user_session: user_session} ->
        Plausible.Repo.get(Plausible.Auth.User, user_session.user_id)
      end)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.flash_messages flash={@flash} />
      <.live_component
        module={PlausibleWeb.Live.Shields.CountryRules}
        current_user={@current_user}
        country_rules_count={@country_rules_count}
        site={@site}
        id="country-rules-#{@current_user.id}"
      />
    </div>
    """
  end

  def handle_info({:flash, kind, message}, socket) do
    socket = put_live_flash(socket, kind, message)
    {:noreply, socket}
  end
end
