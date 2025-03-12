defmodule PlausibleWeb.HelpScoutView do
  use PlausibleWeb, :view

  def render("callback.html", assigns) do
    ~H"""
    <.layout xhr?={assigns[:xhr?]}>
      <div class="search">
        <form action="/helpscout/search">
          <p class="entry">
            <input type="text" name="term" value={assigns[:email]} />
            <input type="submit" name="search" value="&nbsp;&#x1F50E;&nbsp;" />
          </p>
          <input type="hidden" name="token" value={@token} />
          <input type="hidden" name="conversation_id" value={@conversation_id} />
          <input type="hidden" name="customer_id" value={@customer_id} />
        </form>
      </div>

      <%= cond do %>
        <% @conn.assigns[:error] -> %>
          <p>
            Failed to get details: {@error}
          </p>
        <% @multiple_teams? -> %>
          <div class="teams">
            <p class="label">
              <a href={@user_link} target="_blank">Owner</a> of teams:
            </p>

            <div class="value">
              <ul>
                <li :for={team <- @teams}>
                  <a
                    onclick={"loadContent('/helpscout/show?#{URI.encode_query(
                    email: @email, 
                    conversation_id: @conversation_id, 
                    customer_id: @customer_id, 
                    team_identifier: team.identifier, 
                    token: @token)}')"}
                    href="#"
                  >
                    {team.name} ({team.sites_count} sites)
                  </a>
                </li>
              </ul>
            </div>
          </div>

          <div :if={@notes} class="notes">
            <p class="label">
              <b>User notes</b>
            </p>

            <div class="value">
              {PhoenixHTMLHelpers.Format.text_to_html(@notes, escape: true)}
            </div>
          </div>
        <% true -> %>
          <div :if={@team_setup?} class="team-name">
            <p class="label">
              Team name
            </p>
            <p class="value">
              <a href={@status_link} target="_blank">{@team_name}</a>
            </p>
          </div>

          <div class="status">
            <p class="label">
              Status
            </p>
            <p class="value">
              <a href={@status_link} target="_blank">{@status_label}</a>
            </p>
          </div>

          <div class="plan">
            <p class="label">
              Plan
            </p>
            <p class="value">
              <a href={@plan_link} target="_blank">{@plan_label}</a>
            </p>
          </div>

          <div class="sites">
            <p class="label">
              Owner of <b><a href={@sites_link} target="_blank">{@sites_count} sites</a></b>
            </p>
            <p class="value"></p>
          </div>

          <div :if={@notes} class="notes">
            <p class="label">
              <b>Notes</b>
            </p>

            <div class="value">
              {PhoenixHTMLHelpers.Format.text_to_html(@notes, escape: true)}
            </div>
          </div>
      <% end %>
    </.layout>
    """
  end

  def render("search.html", assigns) do
    ~H"""
    <.layout>
      <%= if @conn.assigns[:error] do %>
        <p>
          Failed to run search: {@error}
        </p>
      <% else %>
        <div class="search">
          <form action="/helpscout/search">
            <p class="entry">
              <input type="text" name="term" value={@term} />
              <input type="submit" name="search" value="&nbsp;&#x1F50E;&nbsp;" />
            </p>
            <input type="hidden" name="token" value={@token} />
            <input type="hidden" name="conversation_id" value={@conversation_id} />
            <input type="hidden" name="customer_id" value={@customer_id} />
          </form>
          <ul :if={length(@users) > 0}>
            <li :for={user <- @users}>
              <a
                onclick={"loadContent('/helpscout/show?#{URI.encode_query(email: user.email, conversation_id: @conversation_id, customer_id: @customer_id, token: @token)}')"}
                href="#"
              >
                {user.email} ({user.sites_count} sites)
              </a>
            </li>
          </ul>
          <div :if={@users == []}>
            No match found
          </div>
        </div>
      <% end %>
    </.layout>
    """
  end

  def render("bad_request.html", assigns) do
    ~H"""
    <.layout>
      <p>Missing expected parameters</p>
    </.layout>
    """
  end

  attr :xhr?, :boolean, default: false
  slot :inner_block, required: true

  defp layout(assigns) do
    if assigns.xhr? do
      ~H"""
      render_slot(@inner_block)
      """
    else
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

            ul {
              list-style-type: none;
            }

            p, ul {
              margin-left: 1.25em;
            }

            .entry {
              width: 100%;
              display: flex;
            }

            ul li, .entry {
              margin-bottom: 1.25em;
            }

            .teams .label {
              margin-bottom: 1em;
            }

            .value {
              margin-bottom: 1.25em;
              font-weight: bold;
            }

            .notes .value {
              font-weight: normal;
            }
          </style>
        </head>

        <body>
          <div id="content">
            {render_slot(@inner_block)}
          </div>

          <script type="text/javascript">
            /*
             * HelpScout call adjusting iframe height.
             *
             * Extracted from their JavaScript SDK and adapted.
             */
            function setAppHeight(height) {
              window.parent.postMessage(
                {
                  value: height + 30,
                  type: 'SET_APP_HEIGHT',
                  appId: window.name && window.name.replace(/app-side-panel-|app-/, ''),
                  iframeId: window.name
                },
                'https://secure.helpscout.net/'
              )
            }

            const appContainer = document.getElementById("content")

            async function loadContent(uri) {
              const response = await fetch(uri)
              const html = await response.text()
              appContainer.innerHTML = html
              setAppHeight(appContainer.clientHeight)
            }

            setAppHeight(appContainer.clientHeight)

            /*
             * Tracking any resize of integration content
             * and adjusting iframe height accordingly.
             */
            const resizeObserver = new ResizeObserver(() => {
              setAppHeight(appContainer.clientHeight)
            })

            resizeObserver.observe(appContainer)
          </script>
        </body>
      </html>
      """
    end
  end
end
