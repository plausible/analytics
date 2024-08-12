defmodule PlausibleWeb.HelpScoutController do
  use PlausibleWeb, :controller

  alias Plausible.HelpScout

  @conversation_cookie "helpscout_conversation"
  @conversation_cookie_seconds 8 * 60 * 60
  @signature_errors HelpScout.signature_errors()

  plug :make_iframe_friendly

  def callback(conn, %{"customer-id" => customer_id, "conversation-id" => conversation_id}) do
    assigns = %{conversation_id: conversation_id, customer_id: customer_id}

    with :ok <- HelpScout.validate_signature(conn),
         {:ok, details} <- HelpScout.get_details_for_customer(customer_id) do
      conn
      |> set_cookie(conversation_id)
      |> render("callback.html", Map.merge(assigns, details))
    else
      {:error, {:user_not_found, [email | _]}} ->
        conn
        |> set_cookie(conversation_id)
        |> render("callback.html", Map.merge(assigns, %{error: ":user_not_found", email: email}))

      {:error, error} ->
        conn
        |> maybe_set_cookie(error, conversation_id)
        |> render("callback.html", Map.put(assigns, :error, inspect(error)))
    end
  end

  def callback(conn, _) do
    render(conn, "bad_request.html")
  end

  def show(
        conn,
        %{"email" => email, "conversation_id" => conversation_id, "customer_id" => customer_id} =
          params
      ) do
    assigns = %{
      xhr?: params["xhr"] == "true",
      conversation_id: conversation_id,
      customer_id: customer_id
    }

    with :ok <- match_conversation(conn, conversation_id),
         {:ok, details} <- HelpScout.get_details_for_emails([email], customer_id) do
      render(conn, "callback.html", Map.merge(assigns, details))
    else
      {:error, :invalid_conversation = error} ->
        conn
        |> clear_cookie()
        |> render("callback.html", Map.put(assigns, :error, inspect(error)))

      {:error, error} ->
        render(conn, "callback.html", Map.put(assigns, :error, inspect(error)))
    end
  end

  def search(conn, %{
        "term" => term,
        "conversation_id" => conversation_id,
        "customer_id" => customer_id
      }) do
    assigns = %{
      conversation_id: conversation_id,
      customer_id: customer_id
    }

    case match_conversation(conn, conversation_id) do
      :ok ->
        users = HelpScout.search_users(term, customer_id)
        render(conn, "search.html", Map.merge(assigns, %{users: users, term: term}))

      {:error, :invalid_conversation = error} ->
        conn
        |> clear_cookie()
        |> render("search.html", Map.put(assigns, :error, inspect(error)))
    end
  end

  defp match_conversation(conn, conversation_id) do
    conn = fetch_cookies(conn, encrypted: [@conversation_cookie])
    cookie_conversation = conn.cookies[@conversation_cookie][:conversation_id]

    if cookie_conversation && conversation_id == cookie_conversation do
      :ok
    else
      {:error, :invalid_conversation}
    end
  end

  defp maybe_set_cookie(conn, error, conversation_id)
       when error not in @signature_errors do
    set_cookie(conn, conversation_id)
  end

  defp maybe_set_cookie(conn, _error, _conversation_id) do
    clear_cookie(conn)
  end

  # Exposed for testing
  @doc false
  def set_cookie(conn, conversation_id) do
    put_resp_cookie(conn, @conversation_cookie, %{conversation_id: conversation_id},
      domain: PlausibleWeb.Endpoint.host(),
      secure: true,
      encrypt: true,
      max_age: @conversation_cookie_seconds,
      same_site: "None"
    )
  end

  defp clear_cookie(conn) do
    delete_resp_cookie(conn, @conversation_cookie,
      domain: PlausibleWeb.Endpoint.host(),
      secure: true,
      encrypt: true,
      max_age: @conversation_cookie_seconds,
      same_site: "None"
    )
  end

  defp make_iframe_friendly(conn, _opts) do
    conn
    |> delete_resp_header("x-frame-options")
    |> put_layout(false)
  end
end
