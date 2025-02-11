defmodule Plausible.HelpScoutTest do
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test
  use Plausible

  @moduletag :ee_only

  on_ee do
    alias Plausible.Billing.Subscription
    alias Plausible.HelpScout
    alias Plausible.Repo

    require Plausible.Billing.Subscription.Status

    @v4_business_monthly_plan_id "857105"
    @v4_business_yearly_plan_id "857087"

    describe "validate_signature/1" do
      test "returns error on missing signature" do
        conn =
          :get
          |> Plug.Test.conn("/?foo=one&bar=two&baz=three")
          |> Plug.Conn.fetch_query_params()

        assert {:error, :missing_signature} = HelpScout.validate_signature(conn)
      end

      test "returns error on invalid signature" do
        conn =
          :get
          |> Plug.Test.conn("/?foo=one&bar=two&baz=three&X-HelpScout-Signature=invalid")
          |> Plug.Conn.fetch_query_params()

        assert {:error, :bad_signature} = HelpScout.validate_signature(conn)
      end

      test "passes for valid signature" do
        signature_key = Application.fetch_env!(:plausible, HelpScout)[:signature_key]
        data = ~s|{"foo":"one","bar":"two","baz":"three"}|

        signature =
          :hmac
          |> :crypto.mac(:sha, signature_key, data)
          |> Base.encode64()
          |> URI.encode_www_form()

        conn =
          :get
          |> Plug.Test.conn("/?foo=one&bar=two&baz=three&X-HelpScout-Signature=#{signature}")
          |> Plug.Conn.fetch_query_params()

        assert :ok = HelpScout.validate_signature(conn)
      end
    end

    describe "get_details_for_customer/2" do
      test "returns details for user on trial" do
        %{email: email} = user = new_user(trial_expiry_date: Date.utc_today())
        stub_help_scout_requests(email)
        team = team_of(user)

        crm_url = "#{PlausibleWeb.Endpoint.url()}/crm/teams/team/#{team.id}"

        owned_sites_url =
          "#{PlausibleWeb.Endpoint.url()}/crm/sites/site?custom_search=#{URI.encode_www_form(email)}"

        assert {:ok,
                %{
                  status_link: ^crm_url,
                  status_label: "Trial",
                  plan_link: "#",
                  plan_label: "None",
                  sites_count: 0,
                  sites_link: ^owned_sites_url
                }} = HelpScout.get_details_for_customer("500")
      end

      test "returns for user without trial or subscription" do
        %{email: email} = new_user(trial_expiry_date: nil)
        stub_help_scout_requests(email)

        assert {:ok,
                %{
                  status_link: _,
                  status_label: "None",
                  plan_link: "#",
                  plan_label: "None"
                }} = HelpScout.get_details_for_customer("500")
      end

      test "returns for user with trial expired" do
        %{email: email} =
          new_user(trial_expiry_date: Date.add(Date.utc_today(), -1))

        stub_help_scout_requests(email)

        assert {:ok,
                %{
                  status_link: _,
                  status_label: "Expired trial",
                  plan_link: "#",
                  plan_label: "None"
                }} = HelpScout.get_details_for_customer("500")
      end

      test "returns for user with paid subscription on standard plan" do
        user = %{email: email} = new_user(trial_expiry_date: Date.add(Date.utc_today(), -1))

        subscribe_to_plan(user, @v4_business_monthly_plan_id)

        paddle_subscription_id =
          user
          |> team_of(with_subscription?: true)
          |> Map.fetch!(:subscription)
          |> Map.fetch!(:paddle_subscription_id)

        stub_help_scout_requests(email)

        plan_link =
          "https://vendors.paddle.com/subscriptions/customers/manage/#{paddle_subscription_id}"

        assert {:ok,
                %{
                  status_link: _,
                  status_label: "Paid",
                  plan_link: ^plan_link,
                  plan_label: "10k Plan (€10 monthly)"
                }} = HelpScout.get_details_for_customer("500")
      end

      test "returns for user with paid subscription on standard yearly plan" do
        user = %{email: email} = new_user(trial_expiry_date: Date.add(Date.utc_today(), -1))

        subscribe_to_plan(user, @v4_business_yearly_plan_id)

        paddle_subscription_id =
          user
          |> team_of(with_subscription?: true)
          |> Map.fetch!(:subscription)
          |> Map.fetch!(:paddle_subscription_id)

        stub_help_scout_requests(email)

        plan_link =
          "https://vendors.paddle.com/subscriptions/customers/manage/#{paddle_subscription_id}"

        assert {:ok,
                %{
                  status_link: _,
                  status_label: "Paid",
                  plan_link: ^plan_link,
                  plan_label: "10k Plan (€100 yearly)"
                }} = HelpScout.get_details_for_customer("500")
      end

      test "returns for user with paid subscription on free 10k plan" do
        user = %{email: email} = new_user(trial_expiry_date: Date.add(Date.utc_today(), -1))

        subscribe_to_plan(user, "free_10k")

        stub_help_scout_requests(email)

        assert {:ok,
                %{
                  status_link: _,
                  status_label: "Paid",
                  plan_link: _,
                  plan_label: "Free 10k"
                }} = HelpScout.get_details_for_customer("500")
      end

      test "returns for user with paid subscription on enterprise plan" do
        user = %{email: email} = new_user(trial_expiry_date: Date.add(Date.utc_today(), -1))

        subscribe_to_enterprise_plan(user,
          features: [Plausible.Billing.Feature.StatsAPI]
        )

        stub_help_scout_requests(email)

        assert {:ok,
                %{
                  status_link: _,
                  status_label: "Paid",
                  plan_link: _,
                  plan_label: "1M Enterprise Plan (€10 monthly)"
                }} = HelpScout.get_details_for_customer("500")
      end

      test "returns for user with paid subscription on yearly enterprise plan" do
        user = %{email: email} = new_user(trial_expiry_date: Date.add(Date.utc_today(), -1))

        subscribe_to_enterprise_plan(user,
          features: [Plausible.Billing.Feature.StatsAPI],
          billing_interval: :yearly
        )

        stub_help_scout_requests(email)

        assert {:ok,
                %{
                  status_link: _,
                  status_label: "Paid",
                  plan_link: _,
                  plan_label: "1M Enterprise Plan (€10 yearly)"
                }} = HelpScout.get_details_for_customer("500")
      end

      test "returns for user with subscription pending cancellation" do
        user = %{email: email} = new_user(trial_expiry_date: Date.add(Date.utc_today(), -1))

        subscribe_to_plan(user, @v4_business_monthly_plan_id,
          status: Subscription.Status.deleted()
        )

        stub_help_scout_requests(email)

        assert {:ok,
                %{
                  status_link: _,
                  status_label: "Pending cancellation",
                  plan_link: _,
                  plan_label: "10k Plan (€10 monthly)"
                }} = HelpScout.get_details_for_customer("500")
      end

      test "returns for user with canceled subscription" do
        user = %{email: email} = new_user(trial_expiry_date: Date.add(Date.utc_today(), -1))

        subscribe_to_plan(user, @v4_business_monthly_plan_id,
          status: Subscription.Status.deleted(),
          next_bill_date: Date.add(Date.utc_today(), -1)
        )

        stub_help_scout_requests(email)

        assert {:ok,
                %{
                  status_link: _,
                  status_label: "Canceled",
                  plan_link: _,
                  plan_label: "10k Plan (€10 monthly)"
                }} = HelpScout.get_details_for_customer("500")
      end

      test "returns for user with paused subscription" do
        user = %{email: email} = new_user(trial_expiry_date: Date.add(Date.utc_today(), -1))

        subscribe_to_plan(user, @v4_business_monthly_plan_id,
          status: Subscription.Status.paused()
        )

        stub_help_scout_requests(email)

        assert {:ok,
                %{
                  status_link: _,
                  status_label: "Paused",
                  plan_link: _,
                  plan_label: "10k Plan (€10 monthly)"
                }} = HelpScout.get_details_for_customer("500")
      end

      test "returns for user with locked site" do
        user = %{email: email} = new_user(trial_expiry_date: Date.add(Date.utc_today(), -1))

        new_site(owner: user, locked: true)
        subscribe_to_plan(user, @v4_business_monthly_plan_id)

        stub_help_scout_requests(email)

        assert {:ok,
                %{
                  status_link: _,
                  status_label: "Dashboard locked",
                  plan_link: _,
                  plan_label: "10k Plan (€10 monthly)",
                  sites_count: 1
                }} = HelpScout.get_details_for_customer("500")
      end

      test "returns error when no matching user found in database" do
        new_user()

        stub_help_scout_requests("another@example.com")

        assert {:error, {:user_not_found, ["another@example.com"]}} =
                 HelpScout.get_details_for_customer("500")
      end

      test "returns error when no customer found in Help Scout" do
        Req.Test.stub(HelpScout, fn
          %{request_path: "/v2/oauth2/token"} = conn ->
            Req.Test.json(conn, %{
              "token_type" => "bearer",
              "access_token" => "369dbb08be58430086d2f8bd832bc1eb",
              "expires_in" => 172_800
            })

          %{request_path: "/v2/customers/500"} = conn ->
            conn
            |> Plug.Conn.put_status(404)
            |> Req.Test.text("Not found")
        end)

        assert {:error, :not_found} = HelpScout.get_details_for_customer("500")
      end

      test "returns error when found customer has no emails" do
        Req.Test.stub(HelpScout, fn
          %{request_path: "/v2/oauth2/token"} = conn ->
            Req.Test.json(conn, %{
              "token_type" => "bearer",
              "access_token" => "369dbb08be58430086d2f8bd832bc1eb",
              "expires_in" => 172_800
            })

          %{request_path: "/v2/customers/500"} = conn ->
            Req.Test.json(conn, %{
              "id" => 500,
              "_embedded" => %{
                "emails" => []
              }
            })
        end)

        assert {:error, :no_emails} = HelpScout.get_details_for_customer("500")
      end

      test "uses existing access token when available" do
        %{email: email} = new_user()
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        Repo.insert_all("help_scout_credentials", [
          [
            access_token: HelpScout.Vault.encrypt!("VerySecret"),
            inserted_at: now,
            updated_at: now
          ]
        ])

        Req.Test.stub(HelpScout, fn %{request_path: "/v2/customers/500"} = conn ->
          Req.Test.json(conn, %{
            "id" => 500,
            "_embedded" => %{
              "emails" => [
                %{
                  "id" => 1,
                  "value" => email,
                  "type" => "home"
                }
              ]
            }
          })
        end)

        assert {:ok, _} = HelpScout.get_details_for_customer("500")
      end

      test "refreshes token on expiry" do
        %{email: email} = new_user()
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        Repo.insert_all("help_scout_credentials", [
          [
            access_token: HelpScout.Vault.encrypt!("VerySecretExpired"),
            inserted_at: now,
            updated_at: now
          ]
        ])

        Req.Test.stub(HelpScout, fn
          %{request_path: "/v2/oauth2/token"} = conn ->
            Req.Test.json(conn, %{
              "token_type" => "bearer",
              "access_token" => "VerySecretNew",
              "expires_in" => 172_800
            })

          %{request_path: "/v2/customers/500"} = conn ->
            case Plug.Conn.get_req_header(conn, "authorization") do
              ["Bearer VerySecretExpired"] ->
                conn
                |> Plug.Conn.put_status(401)
                |> Req.Test.text("Token expired")

              ["Bearer VerySecretNew"] ->
                Req.Test.json(conn, %{
                  "id" => 500,
                  "_embedded" => %{
                    "emails" => [
                      %{
                        "id" => 1,
                        "value" => email,
                        "type" => "home"
                      }
                    ]
                  }
                })
            end
        end)

        assert {:ok, _} = HelpScout.get_details_for_customer("500")
      end
    end

    describe "get_details_for_emails/2" do
      test "returns details for user and persists mapping" do
        %{email: email} = user = new_user(trial_expiry_date: Date.utc_today())
        team = team_of(user)

        crm_url = "#{PlausibleWeb.Endpoint.url()}/crm/teams/team/#{team.id}"

        owned_sites_url =
          "#{PlausibleWeb.Endpoint.url()}/crm/sites/site?custom_search=#{URI.encode_www_form(email)}"

        assert {:ok,
                %{
                  status_link: ^crm_url,
                  status_label: "Trial",
                  plan_link: "#",
                  plan_label: "None",
                  sites_count: 0,
                  sites_link: ^owned_sites_url
                }} = HelpScout.get_details_for_emails([email], "123")

        assert {:ok, ^email} = HelpScout.lookup_mapping("123")
      end

      test "updates mapping if one already exists" do
        user = new_user()
        %{email: new_email} = new_user()

        HelpScout.set_mapping("123", user.email)

        assert {:ok, _} = HelpScout.get_details_for_emails([new_email], "123")
        assert {:ok, ^new_email} = HelpScout.lookup_mapping("123")
      end

      test "picks the match with largest number of owned sites" do
        user1 = new_user()
        new_site(owner: user1)
        add_guest(new_site(), user: user1, role: :viewer)
        add_guest(new_site(), user: user1, role: :editor)

        user2 = new_user()
        new_site(owner: user2)
        new_site(owner: user2)
        team2 = team_of(user2)

        crm_url = "#{PlausibleWeb.Endpoint.url()}/crm/teams/team/#{team2.id}"

        owned_sites_url =
          "#{PlausibleWeb.Endpoint.url()}/crm/sites/site?custom_search=#{URI.encode_www_form(user2.email)}"

        assert {:ok,
                %{
                  status_link: ^crm_url,
                  status_label: "Trial",
                  plan_link: "#",
                  plan_label: "None",
                  sites_count: 2,
                  sites_link: ^owned_sites_url
                }} = HelpScout.get_details_for_emails([user1.email, user2.email], "123")

        user2_email = user2.email
        assert {:ok, ^user2_email} = HelpScout.lookup_mapping("123")
      end

      test "does not persist the mapping when there's no match" do
        assert {:error, {:user_not_found, ["does.not.exist@example.com"]}} =
                 HelpScout.get_details_for_emails(["does.not.exist@example.com"], "123")

        assert {:error, :mapping_not_found} = HelpScout.lookup_mapping("123")
      end
    end

    describe "search_users/2" do
      test "lists matching users by email or site domain ordered by site counts" do
        user1 = new_user(email: "user1@match.example.com")

        user2 = new_user(email: "user2@match.example.com")
        new_site(owner: user2)

        user3 = new_user(email: "user3@umatched.example.com")
        new_site(owner: user3)
        new_site(domain: "big.match.example.com/hit", owner: user3)

        assert HelpScout.search_users("match.example.co", "123") == [
                 %{email: user3.email, sites_count: 2},
                 %{email: user2.email, sites_count: 1},
                 %{email: user1.email, sites_count: 0}
               ]
      end
    end

    defp stub_help_scout_requests(email) do
      Req.Test.stub(HelpScout, fn
        %{request_path: "/v2/oauth2/token"} = conn ->
          Req.Test.json(conn, %{
            "token_type" => "bearer",
            "access_token" => "369dbb08be58430086d2f8bd832bc1eb",
            "expires_in" => 172_800
          })

        %{request_path: "/v2/customers/500"} = conn ->
          Req.Test.json(conn, %{
            "id" => 500,
            "_embedded" => %{
              "emails" => [
                %{
                  "id" => 1,
                  "value" => email,
                  "type" => "home"
                }
              ]
            }
          })
      end)
    end
  end
end
