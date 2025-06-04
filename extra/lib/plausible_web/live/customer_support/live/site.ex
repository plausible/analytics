defmodule PlausibleWeb.CustomerSupport.Live.Site do
  @moduledoc false
  use Plausible.CustomerSupport.Resource, :component

  alias PlausibleWeb.Live.Components.ComboBox
  alias Plausible.Repo
  import Ecto.Query

  def update(%{resource_id: resource_id}, socket) do
    site = Resource.Site.get(resource_id)
    changeset = Plausible.Site.crm_changeset(site, %{})
    form = to_form(changeset)
    {:ok, assign(socket, site: site, form: form)}
  end

  def update(%{tab: "people"}, %{assigns: %{site: site}} = socket) do
    people = Plausible.Sites.list_people(site)

    people =
      (people.invitations ++ people.memberships)
      |> Enum.map(fn p ->
        if Map.has_key?(p, :invitation_id) do
          {:invitation, p.email, p.role}
        else
          {:membership, p.user, p.role}
        end
      end)

    {:ok, assign(socket, people: people, tab: "people")}
  end

  def update(%{tab: "rescue-zone"}, %{assigns: %{site: site}} = socket) do
    first_owner =
      hd(Repo.preload(site, :owners).owners)

    {:ok, assign(socket, tab: "rescue-zone", first_owner: first_owner)}
  end

  def update(_, socket) do
    {:ok, assign(socket, tab: "overview")}
  end

  attr :tab, :string, default: "overview"

  def render(assigns) do
    ~H"""
    <div class="p-6">
      <div class="flex items-center">
        <div class="rounded-full p-1 mr-4">
          <.favicon class="w-8" domain={@site.domain} />
        </div>

        <div>
          <p class="text-xl font-bold sm:text-2xl flex items-center gap-x-2">
            {@site.domain}

            <span
              :if={
                @site.team.accept_traffic_until &&
                  Date.after?(Date.utc_today(), @site.team.accept_traffic_until)
              }
              class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800"
            >
              Rejecting traffic
            </span>

            <span
              :if={@site.ingest_rate_limit_threshold == 0}
              class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800"
            >
              Traffic blocked
            </span>
          </p>
          <p class="text-sm font-medium">
            Timezone: {@site.timezone}
          </p>
          <p class="text-sm font-medium">
            Team:
            <.styled_link patch={"/cs/teams/team/#{@site.team.id}"}>
              {@site.team.name}
            </.styled_link>

            <span
              :if={Plausible.Teams.locked?(@site.team)}
              class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800"
            >
              Locked
            </span>
          </p>
          <p class="text-sm font-medium">
            <span :if={@site.domain_changed_from}>(previously: {@site.domain_changed_from})</span>
          </p>
        </div>
      </div>

      <div>
        <div class="hidden sm:block">
          <nav
            class="isolate flex divide-x dark:divide-gray-900 divide-gray-200 rounded-lg shadow dark:shadow-1"
            aria-label="Tabs"
          >
            <.tab to="overview" tab={@tab}>Overview</.tab>
            <.tab to="people" tab={@tab}>
              People
            </.tab>
            <.tab to="rescue-zone" tab={@tab}>
              Rescue Zone
            </.tab>
          </nav>
        </div>
      </div>

      <.form
        :let={f}
        :if={@tab == "overview"}
        for={@form}
        phx-target={@myself}
        phx-submit="save-site"
        class="mt-8"
      >
        <div class="flex justify-center items-center gap-x-8 pb-8 mb-8 border-b border-gray-200 dark:border-gray-700 w-full text-sm text-center">
          <span>Quick links:</span>

          <.styled_link
            new_tab={true}
            href={Routes.stats_path(PlausibleWeb.Endpoint, :stats, @site.domain, [])}
          >
            Dashboard
          </.styled_link>

          <.styled_link
            new_tab={true}
            href={Routes.site_path(PlausibleWeb.Endpoint, :settings_general, @site.domain, [])}
          >
            Settings
          </.styled_link>

          <.styled_link
            new_tab={true}
            href={"https://plausible.grafana.net/d/BClBG5b4k/ingest-counters-per-domain?orgId=1&from=now-24h&to=now&timezone=browser&var-domain=#{@site.domain}&refresh=10s"}
          >
            Ingest Overview
          </.styled_link>
        </div>

        <.input
          type="select"
          field={f[:timezone]}
          label="Timezone"
          options={Plausible.Timezones.options()}
        />
        <.input type="checkbox" field={f[:public]} label="Public?" />
        <.input type="datetime-local" field={f[:native_stats_start_at]} label="Native Stats Start At" />
        <.input
          type="text"
          field={f[:ingest_rate_limit_threshold]}
          label="Ingest Rate Limit Threshold"
        />
        <.input
          type="text"
          field={f[:ingest_rate_limit_scale_seconds]}
          label="Ingest Rate Limit Scale Seconds"
        />

        <div class="flex justify-between">
          <.button phx-target={@myself} type="submit">
            Save
          </.button>

          <.button
            phx-target={@myself}
            phx-click="delete-site"
            data-confirm="Are you sure you want to delete this site?"
            theme="danger"
          >
            Delete Site
          </.button>
        </div>
      </.form>

      <div :if={@tab == "people"} class="mt-8">
        <.table rows={@people}>
          <:thead>
            <.th>User</.th>
            <.th>Kind</.th>
            <.th>Role</.th>
          </:thead>
          <:tbody :let={{kind, person, role}}>
            <.td :if={kind == :membership}>
              <.styled_link class="flex items-center" patch={"/cs/users/user/#{person.id}"}>
                <img
                  src={Plausible.Auth.User.profile_img_url(person)}
                  class="w-4 rounded-full bg-gray-300 mr-2"
                />
                {person.name}
              </.styled_link>
            </.td>

            <.td :if={kind == :invitation}>
              <div class="flex items-center">
                <img
                  src={Plausible.Auth.User.profile_img_url(person)}
                  class="w-4 rounded-full bg-gray-300 mr-2"
                />
                {person}
              </div>
            </.td>

            <.td :if={kind == :membership}>
              Membership
            </.td>

            <.td :if={kind == :invitation}>
              Invitation
            </.td>
            <.td>{role}</.td>
          </:tbody>
        </.table>
      </div>

      <div :if={@tab == "rescue-zone"} class="mt-8">
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
    </div>
    """
  end

  def render_result(assigns) do
    ~H"""
    <div class="flex-1 -mt-px w-full">
      <div class="w-full flex items-center justify-between space-x-4">
        <.favicon class="w-5" domain={@resource.object.domain} />
        <h3
          class="text-gray-900 font-medium text-lg truncate dark:text-gray-100"
          style="width: calc(100% - 4rem)"
        >
          {@resource.object.domain}
        </h3>

        <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">
          Site
        </span>

        <span :if={Plausible.Teams.locked?(@resource.object.team)} class="inline-flex items-center">
          <Heroicons.lock_closed solid class="inline stroke-2 w-4 h-4 text-red-400 mr-2" />
        </span>
      </div>

      <hr class="mt-4 mb-4 flex-grow border-t border-gray-200 dark:border-gray-600" />
      <div class="text-sm truncate">
        Part of <strong>{@resource.object.team.name}</strong>
        <br />
        owned by {@resource.object.team.owners
        |> Enum.map(& &1.name)
        |> Enum.join(", ")}
      </div>
    </div>
    """
  end

  attr :domain, :string, required: true
  attr :class, :string, required: true

  def favicon(assigns) do
    ~H"""
    <img src={"/favicon/sources/#{@domain}"} class={@class} />
    """
  end

  def handle_event("save-site", %{"site" => params}, socket) do
    changeset = Plausible.Site.crm_changeset(socket.assigns.site, params)

    case Plausible.Repo.update(changeset) do
      {:ok, site} ->
        success(socket, "Site saved")
        {:noreply, assign(socket, site: site, form: to_form(changeset))}

      {:error, changeset} ->
        failure(socket, "Error saving site: #{inspect(changeset.errors)}")
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("delete-site", _, socket) do
    Plausible.Site.Removal.run(socket.assigns.site)

    {:noreply, push_navigate(put_flash(socket, :success, "Site deleted"), to: "/cs")}
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
        success(socket, "Transfer e-mail sent!")

      error ->
        failure(socket, inspect(error))
    end

    {:noreply, socket}
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
    |> Enum.map(fn {email, name} ->
      {email, "#{name} <#{email}>"}
    end)
  end
end
