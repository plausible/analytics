defmodule PlausibleWeb.SharedLinkThemeSelectionPlug do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(%{assigns: %{site: site}} = conn, _opts) do
    if !site do
      PlausibleWeb.ControllerHelpers.render_error(conn, 404) |> halt
    else
      shared_link_key = "shared_link_auth_" <> site.domain
      shared_link_auth = get_session(conn, shared_link_key)

      valid_shared_link =
        shared_link_auth && shared_link_auth[:valid_until] > DateTime.to_unix(Timex.now())

      if valid_shared_link do
        theme_index = Enum.find_index(conn.path_info, fn x -> x == "theme" end)

        selected_theme =
          if(
            theme_index,
            do: Enum.at(conn.path_info, theme_index + 1),
            else: get_session(conn, "selected_theme")
          )

        conn
        |> put_session("selected_theme", selected_theme)
        |> assign(:site, site)
        |> assign(:valid_shared_link, valid_shared_link)
        |> assign(:selected_theme, selected_theme)
      else
        selected_theme = nil

        conn
        |> delete_session("selected_theme")
        |> assign(:site, site)
        |> assign(:valid_shared_link, valid_shared_link)
        |> assign(:selected_theme, selected_theme)
      end
    end
  end
end
