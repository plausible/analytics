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
          <input type="hidden" name="conversation_id" value={@conversation_id} />
          <input type="hidden" name="customer_id" value={@customer_id} />
        </form>
      </div>

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
          <p class="value"></p>
        </div>

        <div :if={@notes} class="notes">
          <p class="label">
            <b>Notes</b>
          </p>

          <div class="value">
            <%= PhoenixHTMLHelpers.Format.text_to_html(@notes, escape: true) %>
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
          Failed to run search: <%= @error %>
        </p>
      <% else %>
        <div class="search">
          <form action="/helpscout/search">
            <p class="entry">
              <input type="text" name="term" value={@term} />
              <input type="submit" name="search" value="&nbsp;&#x1F50E;&nbsp;" />
            </p>
            <input type="hidden" name="conversation_id" value={@conversation_id} />
            <input type="hidden" name="customer_id" value={@customer_id} />
          </form>
          <ul :if={length(@users) > 0}>
            <li :for={user <- @users}>
              <a
                onclick={"loadContent('/helpscout/show?#{URI.encode_query(email: user.email, conversation_id: @conversation_id, customer_id: @customer_id)}')"}
                href="#"
              >
                <%= user.email %> (<%= user.sites_count %> sites)
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
            <%= render_slot(@inner_block) %>
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

            const isSafari = !!(
              navigator.vendor &&
              navigator.vendor.indexOf('Apple') > -1 &&
              navigator.userAgent &&
              navigator.userAgent.indexOf('CriOS') == -1 &&
              navigator.userAgent.indexOf('FxiOS') == -1
            )

            /*
             * Using cookies within iframe requires requesting storage access
             * in Safari. Unfortunately, the storage access check sometimes
             * falsely returns true in FireFox and requesting storage access
             * in FF seems to break the cookies. That's why there's an extra
             * check for Safari.
             */
            window.addEventListener('load', async () => {
              const hasStorageAccess = await document.hasStorageAccess()
              if (isSafari && !hasStorageAccess) {
                const paragraph = document.createElement('p')
                paragraph.style = "text-align: center; margin-bottom: 0.4em;"
                const button = document.createElement('button')
                button.innerHTML = 'Grant cookie access'
                button.onclick = async (e) => {
                  await document.requestStorageAccess()
                  paragraph.remove()
                }
                paragraph.append(button)
                appContainer.prepend(paragraph)
              }
            })

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
