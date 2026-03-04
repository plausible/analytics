defmodule Plausible.PlainCustomerCards do
  @moduledoc """
  Plain customer cards API logic.

  Plain sends a POST request with the customer's email and we respond
  with structured card components showing subscription status, plan, etc.
  """

  import Ecto.Query

  alias Plausible.Billing
  alias Plausible.Billing.Subscription
  alias Plausible.Repo
  alias Plausible.Teams

  alias PlausibleWeb.Router.Helpers, as: Routes

  require Plausible.Billing.Subscription.Status

  @spec build_cards(String.t() | nil, [String.t()]) :: [map()]
  def build_cards(email, card_keys) do
    case get_customer_data(email || "") do
      {:ok, details} ->
        card = build_card(details)
        Enum.map(card_keys, fn _key -> card end)

      {:error, _} ->
        Enum.map(card_keys, fn key ->
          %{
            key: key,
            timeToLiveSeconds: 60,
            components: [
              %{componentText: %{text: "Customer not found", textSize: "M", textColor: "MUTED"}}
            ]
          }
        end)
    end
  end

  @spec get_customer_data(String.t()) :: {:ok, map()} | {:error, any()}
  defp get_customer_data(email) do
    user =
      users_query()
      |> where([user: u], u.email == ^email)
      |> Repo.one()

    if user do
      teams = Teams.Users.owned_teams(user)

      if length(teams) > 1 do
        teams =
          teams
          |> Enum.map(fn team ->
            %{
              name: Teams.name(team),
              identifier: team.identifier,
              sites_count: Teams.owned_sites_count(team)
            }
          end)

        user_link =
          Routes.customer_support_user_url(
            PlausibleWeb.Endpoint,
            :show,
            user.id
          )

        {:ok,
         %{
           multiple_teams?: true,
           email: user.email,
           notes: notes(user, nil),
           teams: teams,
           user_link: user_link
         }}
      else
        team = List.first(teams)

        {subscription, plan} =
          if team do
            team = Teams.with_subscription(team)
            plan = Billing.Plans.get_subscription_plan(team.subscription)
            {team.subscription, plan}
          else
            {nil, nil}
          end

        status_link =
          if team do
            Routes.customer_support_team_url(
              PlausibleWeb.Endpoint,
              :show,
              team.id
            )
          else
            Routes.customer_support_user_url(
              PlausibleWeb.Endpoint,
              :show,
              user.id
            )
          end

        {:ok,
         %{
           multiple_teams?: false,
           team_setup?: Plausible.Teams.setup?(team),
           team_name: Plausible.Teams.name(team),
           email: user.email,
           notes: notes(user, team),
           status_label: status_label(team, subscription),
           status_link: status_link,
           plan_label: plan_label(subscription, plan),
           plan_link: plan_link(subscription),
           sites_count: Teams.owned_sites_count(team)
         }}
      end
    else
      {:error, {:user_not_found, email}}
    end
  end

  @spec build_card(map()) :: map()
  defp build_card(%{multiple_teams?: true} = details) do
    %{
      key: "customer-details",
      timeToLiveSeconds: 60,
      components:
        [
          %{
            componentText: %{
              text: "Multiple teams (#{length(details.teams)})",
              textSize: "L",
              textColor: "NORMAL"
            }
          }
        ] ++
          Enum.map(details.teams, fn team ->
            %{
              componentRow: %{
                rowMainContent: [
                  %{componentText: %{text: team.name, textSize: "M", textColor: "NORMAL"}}
                ],
                rowAsideContent: [
                  %{
                    componentText: %{
                      text: "#{team.sites_count} sites",
                      textSize: "S",
                      textColor: "MUTED"
                    }
                  }
                ]
              }
            }
          end) ++
          [
            %{componentDivider: %{dividerSpacingSize: "M"}},
            %{
              componentLinkButton: %{
                linkButtonLabel: "View user in CRM",
                linkButtonUrl: details.user_link
              }
            }
          ]
    }
  end

  defp build_card(%{multiple_teams?: false} = details) do
    components =
      [
        %{
          componentRow: %{
            rowMainContent: [
              %{componentText: %{text: "Status", textSize: "S", textColor: "MUTED"}}
            ],
            rowAsideContent: [
              %{
                componentBadge: %{
                  badgeLabel: details.status_label,
                  badgeColor: status_badge_color(details.status_label)
                }
              }
            ]
          }
        },
        %{
          componentRow: %{
            rowMainContent: [
              %{componentText: %{text: "Plan", textSize: "S", textColor: "MUTED"}}
            ],
            rowAsideContent: [
              %{componentText: %{text: details.plan_label, textSize: "S", textColor: "NORMAL"}}
            ]
          }
        },
        %{
          componentRow: %{
            rowMainContent: [
              %{componentText: %{text: "Sites", textSize: "S", textColor: "MUTED"}}
            ],
            rowAsideContent: [
              %{
                componentText: %{
                  text: to_string(details.sites_count),
                  textSize: "S",
                  textColor: "NORMAL"
                }
              }
            ]
          }
        }
      ] ++
        if details.team_setup? do
          [
            %{
              componentRow: %{
                rowMainContent: [
                  %{componentText: %{text: "Team", textSize: "S", textColor: "MUTED"}}
                ],
                rowAsideContent: [
                  %{
                    componentText: %{
                      text: details.team_name,
                      textSize: "S",
                      textColor: "NORMAL"
                    }
                  }
                ]
              }
            }
          ]
        else
          []
        end

    components =
      if details.notes do
        components ++
          [
            %{componentText: %{text: details.notes, textSize: "S", textColor: "MUTED"}}
          ]
      else
        components
      end

    components =
      components ++
        [
          %{componentDivider: %{dividerSpacingSize: "M"}},
          %{
            componentLinkButton: %{
              linkButtonLabel: "View in CRM",
              linkButtonUrl: details.status_link
            }
          }
        ]

    components =
      if details.plan_link != "#" do
        components ++
          [
            %{
              componentLinkButton: %{
                linkButtonLabel: "Manage in Paddle",
                linkButtonUrl: details.plan_link
              }
            }
          ]
      else
        components
      end

    %{
      key: "customer-details",
      timeToLiveSeconds: 60,
      components: components
    }
  end

  defp status_badge_color(status_label) do
    case status_label do
      "Paid" -> "GREEN"
      "Trial" -> "GREEN"
      "Pending cancellation" -> "YELLOW"
      "Paused" -> "YELLOW"
      "Expired trial" -> "RED"
      "Canceled" -> "RED"
      _ -> "GREY"
    end
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
    trial? = Teams.on_trial?(team)

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

      Teams.locked?(team) ->
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

  defp users_query() do
    from(u in Plausible.Auth.User,
      as: :user,
      left_join: tm in assoc(u, :team_memberships),
      on: tm.role == :owner,
      as: :team_memberships,
      left_join: t in assoc(tm, :team),
      left_join: s in assoc(t, :sites),
      as: :sites,
      where: is_nil(s) or not s.consolidated,
      group_by: u.id,
      order_by: [desc: count(s.id)]
    )
  end

  defp notes(user, team) do
    notes =
      [
        user.notes,
        team && team.notes
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    if notes != "", do: notes
  end
end
