defmodule PlausibleWeb.Live.ChangeDomain.Form do
  @moduledoc """
  Live component for the change domain form
  """
  use PlausibleWeb, :live_component

  alias Plausible.{Repo, Site}

  import Ecto.Query

  def update(assigns, socket) do
    changeset = Site.update_changeset(assigns.site)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(changeset: changeset)
     |> assign(already_owned_domain: nil)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.form :let={f} for={@changeset} phx-submit="submit" phx-target={@myself}>
        <.input
          help_text="Just the naked domain or subdomain without 'www', 'https' etc."
          type="text"
          placeholder="example.com"
          field={f[:domain]}
          label="Domain"
        />

        <p
          :if={@already_owned_domain}
          class="mt-1 flex text-sm text-red-500 leading-4.5 text-pretty"
        >
          You already own this site. See its&nbsp;
          <.styled_link href={Routes.site_path(@socket, :settings_general, @already_owned_domain)}>
            settings
          </.styled_link>
        </p>

        <.button type="submit" class="mt-4 w-full">
          Change Domain
        </.button>
      </.form>
    </div>
    """
  end

  def handle_event("submit", %{"site" => %{"domain" => new_domain}}, socket) do
    site = socket.assigns.site
    preview_changeset = Site.update_changeset(site, %{domain: new_domain})
    cleaned_domain = Ecto.Changeset.get_field(preview_changeset, :domain)

    if same_team_owns_domain?(site, cleaned_domain) do
      {:noreply,
       assign(socket, changeset: preview_changeset, already_owned_domain: cleaned_domain)}
    else
      case Plausible.Site.Domain.change(site, new_domain) do
        {:ok, updated_site} ->
          send(self(), {:domain_changed, updated_site})
          {:noreply, assign(socket, already_owned_domain: nil)}

        {:error, changeset} ->
          {:noreply, assign(socket, changeset: changeset, already_owned_domain: nil)}
      end
    end
  end

  defp same_team_owns_domain?(%Site{id: site_id, team_id: team_id}, domain) do
    Repo.exists?(
      from s in Site, where: s.domain == ^domain and s.team_id == ^team_id and s.id != ^site_id
    )
  end

  defp same_team_owns_domain?(_, _), do: false
end
