defmodule PlausibleWeb.HelpScoutController do
  use PlausibleWeb, :controller

  alias Plausible.HelpScout

  @conversation_token_seconds 8 * 60 * 60

  plug :make_iframe_friendly

  def callback(conn, %{"customer-id" => customer_id, "conversation-id" => conversation_id}) do
    token = sign_token(conversation_id)
    assigns = %{conversation_id: conversation_id, customer_id: customer_id, token: token}

    with :ok <- HelpScout.validate_signature(conn),
         {:ok, details} <- HelpScout.get_details_for_customer(customer_id) do
      conn
      |> render("callback.html", Map.merge(assigns, details))
    else
      {:error, {:user_not_found, [email | _]}} ->
        conn
        |> render("callback.html", Map.merge(assigns, %{error: ":user_not_found", email: email}))

      {:error, error} ->
        conn
        |> render("callback.html", Map.put(assigns, :error, inspect(error)))
    end
  end

  def callback(conn, _) do
    render(conn, "bad_request.html")
  end

  def show(
        conn,
        %{
          "email" => email,
          "token" => token,
          "conversation_id" => conversation_id,
          "customer_id" => customer_id
        } =
          params
      ) do
    assigns = %{
      xhr?: params["xhr"] == "true",
      conversation_id: conversation_id,
      customer_id: customer_id,
      token: token
    }

    with :ok <- match_conversation(token, conversation_id),
         {:ok, details} <-
           HelpScout.get_details_for_emails([email], customer_id, params["team_identifier"]) do
      render(conn, "callback.html", Map.merge(assigns, details))
    else
      {:error, error} ->
        render(conn, "callback.html", Map.put(assigns, :error, inspect(error)))
    end
  end

  def search(conn, %{
        "term" => term,
        "token" => token,
        "conversation_id" => conversation_id,
        "customer_id" => customer_id
      }) do
    assigns = %{
      conversation_id: conversation_id,
      customer_id: customer_id,
      token: token
    }

    case match_conversation(token, conversation_id) do
      :ok ->
        users = HelpScout.search_users(term, customer_id)
        render(conn, "search.html", Map.merge(assigns, %{users: users, term: term}))

      {:error, error} ->
        render(conn, "search.html", Map.put(assigns, :error, inspect(error)))
    end
  end

  defp match_conversation(token, conversation_id) do
    case verify_token(token) do
      {:ok, token_data} ->
        if token_data.conversation_id == conversation_id do
          :ok
        else
          {:error, :invalid_conversation}
        end

      {:error, _error} ->
        {:error, :invalid_token}
    end
  end

  # Exposed for testing
  @doc false
  def sign_token(conversation_id) do
    Phoenix.Token.sign(PlausibleWeb.Endpoint, "hs-conversation", %{
      conversation_id: conversation_id
    })
  end

  defp verify_token(token) do
    Phoenix.Token.verify(PlausibleWeb.Endpoint, "hs-conversation", token,
      max_age: @conversation_token_seconds
    )
  end

  defp make_iframe_friendly(conn, _opts) do
    conn
    |> delete_resp_header("x-frame-options")
    |> put_layout(false)
  end
end
