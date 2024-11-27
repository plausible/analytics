defmodule Plausible.HelpScout do
  @moduledoc """
  HelpScout callback API logic.
  """

  import Ecto.Query

  alias Plausible.Billing
  alias Plausible.Billing.Subscription
  alias Plausible.HelpScout.Vault
  alias Plausible.Repo

  alias PlausibleWeb.Router.Helpers, as: Routes

  require Plausible.Billing.Subscription.Status

  @base_api_url "https://api.helpscout.net"
  @signature_field "X-HelpScout-Signature"

  @signature_errors [:missing_signature, :bad_signature]

  @type signature_error() :: unquote(Enum.reduce(@signature_errors, &{:|, [], [&1, &2]}))

  def signature_errors(), do: @signature_errors

  @doc """
  Validates signature against secret key configured for the
  HelpScout application.

  NOTE: HelpScout signature generation procedure at
  https://developer.helpscout.com/apps/guides/signature-validation/
  fails to mention that it's implicitly dependent on request params
  order getting preserved. PHP arrays are ordered maps, so they provide
  this guarantee. Here, on the other hand, we have to determine the original
  order of the keys directly from the query string and serialize
  params to JSON using wrapper struct, informing Jason to put the values
  in the serialized object in this particular order matching query string.
  """
  @spec validate_signature(Plug.Conn.t()) :: :ok | {:error, signature_error()}
  def validate_signature(conn) do
    params = conn.params

    keys =
      conn.query_string
      |> String.split("&")
      |> Enum.map(fn part ->
        part |> String.split("=") |> List.first()
      end)
      |> Enum.reject(&(&1 == @signature_field))

    signature = params[@signature_field]

    if is_binary(signature) do
      signature_key = Keyword.fetch!(config(), :signature_key)

      ordered_data = Enum.map(keys, fn key -> {key, params[key]} end)
      data = Jason.encode!(%Jason.OrderedObject{values: ordered_data})

      calculated =
        :hmac
        |> :crypto.mac(:sha, signature_key, data)
        |> Base.encode64()

      if Plug.Crypto.secure_compare(signature, calculated) do
        :ok
      else
        {:error, :bad_signature}
      end
    else
      {:error, :missing_signature}
    end
  end

  @spec get_details_for_customer(String.t()) :: {:ok, map()} | {:error, any()}
  def get_details_for_customer(customer_id) do
    with {:ok, emails} <- get_customer_emails(customer_id) do
      get_details_for_emails(emails, customer_id)
    end
  end

  @spec get_details_for_emails([String.t()], String.t()) :: {:ok, map()} | {:error, any()}
  def get_details_for_emails(emails, customer_id) do
    with {:ok, user} <- get_user(emails) do
      set_mapping(customer_id, user.email)

      {team, subscription, plan} =
        case Plausible.Teams.get_by_owner(user) do
          {:ok, team} ->
            team = Plausible.Teams.with_subscription(team)
            plan = Billing.Plans.get_subscription_plan(team.subscription)
            {team, team.subscription, plan}

          {:error, :no_team} ->
            {nil, nil, nil}
        end

      {:ok,
       %{
         email: user.email,
         notes: user.notes,
         status_label: status_label(team, subscription),
         status_link:
           Routes.kaffy_resource_url(PlausibleWeb.Endpoint, :show, :auth, :user, user.id),
         plan_label: plan_label(subscription, plan),
         plan_link: plan_link(subscription),
         sites_count: Plausible.Sites.owned_sites_count(user),
         sites_link:
           Routes.kaffy_resource_url(PlausibleWeb.Endpoint, :index, :sites, :site,
             search: user.email
           )
       }}
    end
  end

  @spec search_users(String.t(), String.t()) :: [map()]
  def search_users(term, customer_id) do
    clear_mapping(customer_id)

    search_term = "%#{term}%"

    domain_query =
      from(s in Plausible.Site,
        inner_join: sm in assoc(s, :memberships),
        where: sm.user_id == parent_as(:user).id and sm.role == :owner,
        where: ilike(s.domain, ^search_term) or ilike(s.domain_changed_from, ^search_term),
        select: 1
      )

    users_query()
    |> where(
      [user: u],
      like(u.email, ^search_term) or exists(domain_query)
    )
    |> limit(5)
    |> select([user: u, site_membership: sm], %{email: u.email, sites_count: count(sm.id)})
    |> Repo.all()
  end

  defp plan_link(nil), do: "#"

  defp plan_link(%{paddle_subscription_id: paddle_id}) do
    Path.join([
      Billing.PaddleApi.vendors_domain(),
      "/subscriptions/customers/manage/",
      paddle_id
    ])
  end

  defp status_label(team, subscription) do
    subscription_active? = Billing.Subscriptions.active?(subscription)
    trial? = Plausible.Teams.on_trial?(team)

    cond do
      not subscription_active? and not trial? and (is_nil(team) or is_nil(team.trial_expiry_date)) ->
        "None"

      is_nil(subscription) and not trial? ->
        "Expired trial"

      trial? ->
        "Trial"

      subscription.status == Subscription.Status.deleted() ->
        if subscription_active? do
          "Pending cancellation"
        else
          "Canceled"
        end

      subscription.status == Subscription.Status.paused() ->
        "Paused"

      Plausible.Teams.owned_sites_locked?(team) ->
        "Dashboard locked"

      subscription_active? ->
        "Paid"
    end
  end

  defp plan_label(_, nil) do
    "None"
  end

  defp plan_label(_, :free_10k) do
    "Free 10k"
  end

  defp plan_label(subscription, %Billing.Plan{} = plan) do
    [plan] = Billing.Plans.with_prices([plan])
    interval = Billing.Plans.subscription_interval(subscription)
    quota = PlausibleWeb.AuthView.subscription_quota(subscription, [])

    price =
      cond do
        interval == "monthly" && plan.monthly_cost ->
          Billing.format_price(plan.monthly_cost)

        interval == "yearly" && plan.yearly_cost ->
          Billing.format_price(plan.yearly_cost)

        true ->
          "N/A"
      end

    "#{quota} Plan (#{price} #{interval})"
  end

  defp plan_label(subscription, %Billing.EnterprisePlan{} = plan) do
    quota = PlausibleWeb.AuthView.subscription_quota(subscription, [])
    price_amount = Billing.Plans.get_price_for(plan, "127.0.0.1")

    price =
      if price_amount do
        Billing.format_price(price_amount)
      else
        "N/A"
      end

    "#{quota} Enterprise Plan (#{price} #{plan.billing_interval})"
  end

  defp get_user(emails) do
    user =
      users_query()
      |> where([user: u], u.email in ^emails)
      |> limit(1)
      |> Repo.one()

    if user do
      {:ok, user}
    else
      {:error, {:user_not_found, emails}}
    end
  end

  defp users_query() do
    from(u in Plausible.Auth.User,
      as: :user,
      left_join: sm in assoc(u, :site_memberships),
      on: sm.role == :owner,
      as: :site_membership,
      left_join: s in assoc(sm, :site),
      as: :site,
      group_by: u.id,
      order_by: [desc: count(sm.id)]
    )
  end

  defp get_customer_emails(customer_id) do
    case lookup_mapping(customer_id) do
      {:ok, email} ->
        {:ok, [email]}

      {:error, :mapping_not_found} ->
        fetch_customer_emails(customer_id)
    end
  end

  defp fetch_customer_emails(customer_id, opts \\ []) do
    refresh? = Keyword.get(opts, :refresh?, true)
    token = get_token!()

    url = Path.join([@base_api_url, "/v2/customers/", customer_id])

    extra_opts = Application.get_env(:plausible, __MODULE__)[:req_opts] || []
    opts = Keyword.merge([auth: {:bearer, token}], extra_opts)

    case Req.get(url, opts) do
      {:ok, %{body: %{"_embedded" => %{"emails" => [_ | _] = emails}}}} ->
        {:ok, Enum.map(emails, & &1["value"])}

      {:ok, %{status: 200}} ->
        {:error, :no_emails}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: 401}} ->
        if refresh? do
          refresh_token!()
          fetch_customer_emails(customer_id, refresh?: false)
        else
          {:error, :auth_failed}
        end

      error ->
        Sentry.capture_message("Failed to obtain customer data from HelpScout API",
          extra: %{error: inspect(error), customer_id: customer_id}
        )

        {:error, :unknown}
    end
  end

  # Exposed for testing
  @doc false
  def lookup_mapping(customer_id) do
    email =
      "SELECT email FROM help_scout_mappings WHERE customer_id = $1"
      |> Repo.query!([customer_id])
      |> Map.get(:rows)
      |> List.first()

    case email do
      [email] ->
        {:ok, email}

      _ ->
        {:error, :mapping_not_found}
    end
  end

  # Exposed for testing
  @doc false
  def set_mapping(customer_id, email) do
    now = NaiveDateTime.utc_now(:second)

    Repo.insert_all(
      "help_scout_mappings",
      [[customer_id: customer_id, email: email, inserted_at: now, updated_at: now]],
      conflict_target: :customer_id,
      on_conflict: [set: [email: email, updated_at: now]]
    )
  end

  defp clear_mapping(customer_id) do
    Repo.query!("DELETE FROM help_scout_mappings WHERE customer_id = $1", [customer_id])
  end

  defp get_token!() do
    token =
      "SELECT access_token FROM help_scout_credentials ORDER BY id DESC LIMIT 1"
      |> Repo.query!()
      |> Map.get(:rows)
      |> List.first()

    case token do
      [token] when is_binary(token) ->
        Vault.decrypt!(token)

      _ ->
        refresh_token!()
    end
  end

  defp refresh_token!() do
    url = Path.join(@base_api_url, "/v2/oauth2/token")
    credentials = config()

    params = [
      grant_type: "client_credentials",
      client_id: Keyword.fetch!(credentials, :app_id),
      client_secret: Keyword.fetch!(credentials, :app_secret)
    ]

    extra_opts = Application.get_env(:plausible, __MODULE__)[:req_opts] || []
    opts = Keyword.merge([form: params], extra_opts)

    %{status: 200, body: %{"access_token" => token}} = Req.post!(url, opts)
    now = NaiveDateTime.utc_now(:second)

    Repo.insert_all("help_scout_credentials", [
      [access_token: Vault.encrypt!(token), inserted_at: now, updated_at: now]
    ])

    token
  end

  defp config() do
    Application.fetch_env!(:plausible, __MODULE__)
  end
end
