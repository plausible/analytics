defmodule PlausibleWeb.HelpScoutView do
  use PlausibleWeb, :view

  def render("callback.html", assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Helpscout Customer Details</title>
        <style type="text/css">
          * {
            margin: 0;
            padding: 0;
          }

          body {
            font-family: Helvetica, Arial, Sans-Serif;
            font-size: 14px;
          }

          p {
            margin-left: 1.25em;
          }

          .value {
            margin-bottom: 1.25em;
            font-weight: bold;
          }
        </style>
      </head>

      <body>
        <%= if @conn.assigns[:error] do %>
          <p>
            Failed to get details: <%= @error %>
          </p>
        <% else %>
          <div class="status">
            <p class="label">
              Status
            </p>
            <p class="value">
              <a href={@status_link} target="_blank"><%= @status_label %></a>
            </p>
          </div>

          <div class="plan">
            <p class="label">
              Plan
            </p>
            <p class="value">
              <a href={@plan_link} target="_blank"><%= @plan_label %></a>
            </p>
          </div>

          <div class="sites">
            <p class="label">
              Owner of <b><a href={@sites_link} target="_blank"><%= @sites_count %> sites</a></b>
            </p>
          </div>
        <% end %>
      </body>
    </html>
    """
  end
end
