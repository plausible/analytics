defmodule Plausible.Billing.EnterprisePlanAdmin do
  use Plausible.Repo

  @numeric_fields [
    "user_id",
    "paddle_plan_id",
    "monthly_pageview_limit",
    "site_limit",
    "team_member_limit",
    "hourly_api_request_limit"
  ]

  def search_fields(_schema) do
    [
      :paddle_plan_id
    ]
  end

  def form_fields(_schema) do
    [
      user_id: nil,
      paddle_plan_id: nil,
      billing_interval: %{choices: [{"Yearly", "yearly"}, {"Monthly", "monthly"}]},
      monthly_pageview_limit: nil,
      site_limit: nil,
      team_member_limit: nil,
      hourly_api_request_limit: nil,
      features: nil
    ]
  end

  def custom_index_query(conn, _schema, query) do
    search =
      (conn.params["custom_search"] || "")
      |> String.trim()
      |> String.replace("%", "\%")
      |> String.replace("_", "\_")

    search_term = "%#{search}%"

    from(r in query,
      inner_join: t in assoc(r, :team),
      inner_join: o in assoc(t, :owner),
      or_where: ilike(r.paddle_plan_id, ^search_term),
      or_where: ilike(o.email, ^search_term) or ilike(o.name, ^search_term),
      preload: [team: {t, owner: o}]
    )
  end

  def custom_show_query(_conn, _schema, query) do
    from(ep in query,
      inner_join: t in assoc(ep, :team),
      inner_join: o in assoc(t, :owner),
      select: %{ep | user_id: o.id}
    )
  end

  def index(_) do
    [
      id: nil,
      user_email: %{value: &get_user_email/1},
      paddle_plan_id: nil,
      billing_interval: nil,
      monthly_pageview_limit: nil,
      site_limit: nil,
      team_member_limit: nil,
      hourly_api_request_limit: nil
    ]
  end

  defp get_user_email(plan), do: plan.team.owner.email

  def create_changeset(schema, attrs) do
    attrs = sanitize_attrs(attrs)

    team_id =
      if user_id = attrs["user_id"] do
        user = Repo.get!(Plausible.Auth.User, user_id)
        {:ok, team} = Plausible.Teams.get_or_create(user)
        team.id
      end

    attrs = Map.put(attrs, "team_id", team_id)

    Plausible.Billing.EnterprisePlan.changeset(struct(schema, %{}), attrs)
  end

  def update_changeset(enterprise_plan, attrs) do
    attrs =
      attrs
      |> Map.put_new("features", [])
      |> sanitize_attrs()

    Plausible.Billing.EnterprisePlan.changeset(enterprise_plan, attrs)
  end

  defp sanitize_attrs(attrs) do
    attrs
    |> Enum.map(&clear_attr/1)
    |> Enum.reject(&(&1 == ""))
    |> Map.new()
  end

  defp clear_attr({key, value}) when key in @numeric_fields do
    value =
      value
      |> to_string()
      |> String.replace(~r/[^0-9-]/, "")
      |> String.trim()

    {key, value}
  end

  defp clear_attr({key, value}) when is_binary(value) do
    {key, String.trim(value)}
  end

  defp clear_attr(other) do
    other
  end
end
