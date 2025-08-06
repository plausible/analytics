defmodule PlausibleWeb.CustomerSupport.Site.Components.RescueZone do
  @moduledoc """
  Site rescue zone component - handles site transfer functionality
  """
  use PlausibleWeb, :live_component
  import PlausibleWeb.CustomerSupport.Live
  import PlausibleWeb.Components.Generic
  import Ecto.Query
  alias Plausible.Repo
  alias PlausibleWeb.Live.Components.ComboBox

  def update(%{site: site}, socket) do
    first_owner =
      hd(Repo.preload(site, :owners).owners)

    {:ok, assign(socket, site: site, first_owner: first_owner)}
  end

  def render(assigns) do
    ~H"""
    <div class="mt-8">
      <h1 class="text-xs font-semibold">Transfer Site</h1>
      <form class="mt-4 mb-8" phx-target={@myself} phx-submit="init-transfer">
        <.label for="inviter_email">
          Initiate transfer as
        </.label>
        <.live_component
          id="inviter_email"
          submit_name="inviter_email"
          class={[
            "mb-4"
          ]}
          module={ComboBox}
          suggest_fun={fn input, _ -> search_email(input) end}
          selected={{@first_owner.email, "#{@first_owner.name} <#{@first_owner.email}>"}}
        />

        <.label for="invitee_email">
          Send transfer invitation to
        </.label>
        <.live_component
          id="invitee_email"
          submit_name="invitee_email"
          module={ComboBox}
          suggest_fun={fn input, _ -> search_email(input) end}
          creatable
        />
        <.button phx-target={@myself} type="submit">
          Initiate Site Transfer
        </.button>
      </form>
    </div>
    """
  end

  def handle_event("init-transfer", params, socket) do
    inviter = Plausible.Repo.get_by!(Plausible.Auth.User, email: params["inviter_email"])

    case Plausible.Teams.Invitations.InviteToSite.invite(
           socket.assigns.site,
           inviter,
           params["invitee_email"],
           :owner
         ) do
      {:ok, _transfer} ->
        success("Transfer e-mail sent!")
        {:noreply, socket}

      error ->
        failure("Transfer failed: #{inspect(error)}")
        {:noreply, socket}
    end
  end

  defp search_email(input) do
    Repo.all(
      from u in Plausible.Auth.User,
        where: ilike(u.name, ^"%#{input}%") or ilike(u.email, ^"%#{input}%"),
        limit: 20,
        order_by: [
          desc: fragment("?.name = ?", u, ^input),
          desc: fragment("?.email = ?", u, ^input),
          asc: u.name
        ],
        select: {u.email, u.name}
    )
    |> Enum.map(fn {email, name} -> {email, "#{name} <#{email}>"} end)
  end
end
