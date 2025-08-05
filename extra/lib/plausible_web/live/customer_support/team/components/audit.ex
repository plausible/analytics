defmodule PlausibleWeb.CustomerSupport.Team.Components.Audit do
  @moduledoc """
  Team audit component - handles audit log viewing
  """
  use PlausibleWeb, :live_component

  def update(%{team: team, tab_params: tab_params}, socket) do
    pagination_params = get_pagination_params(tab_params)
    audit_page = Plausible.Audit.list_entries_paginated([team_id: team.id], pagination_params)

    entries = process_audit_entries(audit_page.entries)
    audit_page = %{audit_page | entries: entries}
    current_limit = pagination_params["limit"]

    {:ok,
     assign(socket,
       team: team,
       audit_page: audit_page,
       revealed_audit_entry_id: nil,
       current_limit: current_limit
     )}
  end

  def update(%{team: team}, socket) do
    update(%{team: team, tab_params: %{}}, socket)
  end

  def render(assigns) do
    ~H"""
    <div class="mt-4 mb-4 text-gray-900 dark:text-gray-400 relative">
      <div :if={Enum.empty?(@audit_page.entries)} class="flex justify-center items-center">
        No audit logs yet
      </div>

      <div
        :if={@revealed_audit_entry_id}
        phx-target={@myself}
        phx-window-keydown="reveal-audit-entry"
        phx-key="escape"
      >
        <.input_with_clipboard
          id="audit-entry-identifier"
          name="audit-entry-identifier"
          label="Audit Entry Identifier"
          value={@revealed_audit_entry_id}
        />
        <div class="relative">
          <.input
            rows="16"
            type="textarea"
            id="audit-entry-change"
            name="audit-entry-change"
            value={
              Jason.encode!(
                Enum.find(@audit_page.entries, &(&1.id == @revealed_audit_entry_id)).change,
                pretty: true
              )
            }
          >
          </.input>
          <.styled_link
            class="text-sm float-right"
            onclick="var textarea = document.getElementById('audit-entry-change'); textarea.focus(); textarea.select(); document.execCommand('copy');"
            href="#"
          >
            <div class="flex items-center absolute top-4 right-4 text-xs gap-x-1">
              <Heroicons.document_duplicate class="h-4 w-4 text-indigo-700" /> COPY
            </div>
          </.styled_link>

          <.styled_link
            phx-click="reveal-audit-entry"
            phx-target={@myself}
            class="float-right pt-4 text-sm"
          >
            &larr; Return
            <kbd class="rounded border border-gray-200 dark:border-gray-600 px-2 font-mono font-normal text-xs text-gray-400">
              ESC
            </kbd>
          </.styled_link>
        </div>
      </div>

      <.table :if={is_nil(@revealed_audit_entry_id)} rows={@audit_page.entries}>
        <:thead>
          <.th invisible></.th>
          <.th invisible></.th>
          <.th>Name</.th>
          <.th>Entity</.th>
          <.th>Actor</.th>
          <.th invisible>Actions</.th>
        </:thead>
        <:tbody :let={entry}>
          <.td>{Calendar.strftime(entry.datetime, "%Y-%m-%d")}</.td>
          <.td>{Calendar.strftime(entry.datetime, "%H:%M:%S")}</.td>
          <.td class="font-mono">{entry.name}</.td>
          <.td truncate>
            <.audit_entity entry={entry} />
          </.td>
          <.td :if={entry.actor_type == :system}>
            <div class="flex items-center gap-x-1">
              <Heroicons.cog_6_tooth class="size-4" /> SYSTEM
            </div>
          </.td>
          <.td :if={entry.actor_type == :user} truncate>
            <.audit_user user={entry.meta.user} />
          </.td>

          <.td actions>
            <.edit_button
              phx-click="reveal-audit-entry"
              icon={:magnifying_glass_plus}
              phx-value-id={entry.id}
              phx-target={@myself}
            />
          </.td>
        </:tbody>
      </.table>

      <div
        :if={
          is_nil(@revealed_audit_entry_id) &&
            (@audit_page.metadata.before || @audit_page.metadata.after)
        }
        class="flex justify-between items-center mt-4"
      >
        <.button
          :if={@audit_page.metadata.before}
          id="prev-page"
          phx-click="paginate-audit"
          phx-value-before={@audit_page.metadata.before}
          phx-value-limit={@current_limit}
          phx-target={@myself}
          theme="bright"
        >
          &larr; Prev
        </.button>
        <div></div>
        <.button
          :if={@audit_page.metadata.after}
          id="next-page"
          phx-click="paginate-audit"
          phx-value-after={@audit_page.metadata.after}
          phx-value-limit={@current_limit}
          phx-target={@myself}
          theme="bright"
        >
          Next &rarr;
        </.button>
      </div>
    </div>
    """
  end

  def handle_event("reveal-audit-entry", %{"id" => id}, socket) do
    {:noreply, assign(socket, revealed_audit_entry_id: id)}
  end

  def handle_event("reveal-audit-entry", _, socket) do
    {:noreply, assign(socket, revealed_audit_entry_id: nil)}
  end

  def handle_event("paginate-audit", params, socket) do
    pagination_params = get_pagination_params(params)
    team = socket.assigns.team

    query_params = %{"tab" => "audit"} |> Map.merge(pagination_params)

    {:noreply,
     push_patch(socket,
       to: Routes.customer_support_team_path(PlausibleWeb.Endpoint, :show, team.id, query_params)
     )}
  end

  defp process_audit_entries(entries) do
    Enum.map(entries, fn entry ->
      meta = entry.meta

      meta =
        if entry.user_id && entry.user_id > 0 do
          user = Plausible.Repo.get(Plausible.Auth.User, entry.user_id)
          Map.put(meta, :user, user)
        else
          meta
        end

      meta =
        if entry.entity == "Plausible.Auth.User" do
          user = Plausible.Repo.get(Plausible.Auth.User, String.to_integer(entry.entity_id))
          Map.put(meta, :entity, user)
        else
          meta
        end

      Map.put(entry, :meta, meta)
    end)
  end

  attr :entry, Plausible.Audit.Entry

  defp audit_entity(assigns) do
    ~H"""
    <%= if @entry.entity == "Plausible.Auth.User" do %>
      <.audit_user user={@entry.meta.entity} />
    <% else %>
      {@entry.entity |> String.split(".") |> List.last()} #{String.slice(@entry.entity_id, 0, 8)}
    <% end %>
    """
  end

  attr :user, Plausible.Auth.User

  defp audit_user(%{user: nil} = assigns) do
    ~H"""
    (N/A)
    """
  end

  defp audit_user(assigns) do
    ~H"""
    <div class="flex items-center gap-x-1">
      <img
        class="w-4"
        src={
          Plausible.Auth.User.profile_img_url(%Plausible.Auth.User{
            email: @user.email
          })
        }
      />

      <.styled_link
        patch={Routes.customer_support_user_path(PlausibleWeb.Endpoint, :show, @user.id)}
        class="cursor-pointer flex block items-center"
      >
        {@user.name}
      </.styled_link>
    </div>
    """
  end

  defp get_pagination_params(params) do
    params
    |> Map.take(["after", "before", "limit"])
    |> Map.put_new("limit", 15)
  end
end
