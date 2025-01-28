defmodule PlausibleWeb.Plugs.AuthorizePublicAPI do
  @moduledoc """
  Plug for authorizing access to Stats and Sites APIs.

  The plug expects `:api_scope` to be provided in the assigns. The scope
  will then be used to check for API key validity. The assign can be
  provided in the router configuration in a following way:

      scope "/api/v1/stats", PlausibleWeb.Api, assigns: %{api_scope: "some:scope:*"} do
        pipe_through [:public_api, #{inspect(__MODULE__)}]

        # route definitions follow
        # ...
      end

  The scope from `:api_scope` is checked for match against all scopes from API key's
  `scopes` field. If the scope is among `@implicit_scopes`, it's considered to be
  present for any valid API key. Scopes are checked for match by prefix, so if we have
  `some:scope:*` in matching route `:api_scope` and the API key has `some:*` in its
  `scopes` field, they will match.

  After a match is found, additional verification can be conducted, like in case of
  `stats:read:*`, where valid site ID is expected among parameters too.

  All API requests are rate limited per API key, enforcing a given hourly request limit.
  """

  use Plausible.Repo

  import Plug.Conn

  alias Plausible.Auth
  alias Plausible.RateLimit
  alias Plausible.Sites
  alias PlausibleWeb.Api.Helpers, as: H

  # Scopes permitted implicitly for every API key. Existing API keys
  # have _either_ `["stats:read:*"]` (the default) or `["sites:provision:*"]`
  # set as their valid scopes. We always consider implicit scopes as
  # present in addition to whatever else is provided for a particular
  # API key.
  @implicit_scopes ["stats:read:*", "sites:read:*"]

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    requested_scope = Map.fetch!(conn.assigns, :api_scope)

    with {:ok, token} <- get_bearer_token(conn),
         {:ok, api_key} <- Auth.find_api_key(token),
         :ok <- check_api_key_rate_limit(api_key),
         {:ok, conn} <- verify_by_scope(conn, api_key, requested_scope) do
      assign(conn, :current_user, api_key.user)
    else
      error -> send_error(conn, requested_scope, error)
    end
  end

  ### Verification dispatched by scope

  defp verify_by_scope(conn, api_key, "stats:read:" <> _ = scope) do
    with :ok <- check_scope(api_key, scope),
         {:ok, site} <- find_site(conn.params["site_id"]),
         :ok <- verify_site_access(api_key, site) do
      Plausible.OpenTelemetry.add_site_attributes(site)
      site = Plausible.Repo.preload(site, :completed_imports)
      {:ok, assign(conn, :site, site)}
    end
  end

  defp verify_by_scope(conn, api_key, scope) do
    with :ok <- check_scope(api_key, scope) do
      {:ok, conn}
    end
  end

  defp check_scope(_api_key, required_scope) when required_scope in @implicit_scopes do
    :ok
  end

  defp check_scope(api_key, required_scope) do
    found? =
      Enum.any?(api_key.scopes, fn scope ->
        scope = String.trim_trailing(scope, "*")

        String.starts_with?(required_scope, scope)
      end)

    if found? do
      :ok
    else
      {:error, :invalid_api_key}
    end
  end

  defp get_bearer_token(conn) do
    authorization_header =
      conn
      |> Plug.Conn.get_req_header("authorization")
      |> List.first()

    case authorization_header do
      "Bearer " <> token -> {:ok, String.trim(token)}
      _ -> {:error, :missing_api_key}
    end
  end

  defp check_api_key_rate_limit(api_key) do
    case RateLimit.check_rate(
           "api_request:#{api_key.id}",
           to_timeout(hour: 1),
           api_key.hourly_request_limit
         ) do
      {:allow, _} -> :ok
      {:deny, _} -> {:error, :rate_limit, api_key.hourly_request_limit}
    end
  end

  defp find_site(nil), do: {:error, :missing_site_id}

  defp find_site(site_id) do
    domain_based_search =
      from s in Plausible.Site, where: s.domain == ^site_id or s.domain_changed_from == ^site_id

    case Repo.one(domain_based_search) do
      %Plausible.Site{} = site ->
        {:ok, site}

      nil ->
        {:error, :invalid_api_key}
    end
  end

  defp verify_site_access(api_key, site) do
    team =
      case Plausible.Teams.get_by_owner(api_key.user) do
        {:ok, team} -> team
        _ -> nil
      end

    is_member? = Plausible.Teams.Memberships.site_member?(site, api_key.user)
    is_super_admin? = Auth.is_super_admin?(api_key.user_id)

    cond do
      is_super_admin? ->
        :ok

      Sites.locked?(site) ->
        {:error, :site_locked}

      Plausible.Billing.Feature.StatsAPI.check_availability(team) !== :ok ->
        {:error, :upgrade_required}

      is_member? ->
        :ok

      true ->
        {:error, :invalid_api_key}
    end
  end

  defp send_error(conn, _, {:error, :missing_api_key}) do
    H.unauthorized(
      conn,
      "Missing API key. Please use a valid Plausible API key as a Bearer Token."
    )
  end

  defp send_error(conn, "stats:read:" <> _, {:error, :invalid_api_key}) do
    H.unauthorized(
      conn,
      "Invalid API key or site ID. Please make sure you're using a valid API key with access to the site you've requested."
    )
  end

  defp send_error(conn, _, {:error, :invalid_api_key}) do
    H.unauthorized(
      conn,
      "Invalid API key. Please make sure you're using a valid API key with access to the resource you've requested."
    )
  end

  defp send_error(conn, _, {:error, :rate_limit, limit}) do
    H.too_many_requests(
      conn,
      "Too many API requests. Your API key is limited to #{limit} requests per hour. Please contact us to request more capacity."
    )
  end

  defp send_error(conn, _, {:error, :missing_site_id}) do
    H.bad_request(
      conn,
      "Missing site ID. Please provide the required site_id parameter with your request."
    )
  end

  defp send_error(conn, _, {:error, :upgrade_required}) do
    H.payment_required(
      conn,
      "The account that owns this API key does not have access to Stats API. Please make sure you're using the API key of a subscriber account and that the subscription plan includes Stats API"
    )
  end

  defp send_error(conn, _, {:error, :site_locked}) do
    H.payment_required(
      conn,
      "This Plausible site is locked due to missing active subscription. In order to access it, the site owner should subscribe to a suitable plan"
    )
  end
end
