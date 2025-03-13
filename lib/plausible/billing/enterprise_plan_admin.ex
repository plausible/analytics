defmodule Plausible.Billing.EnterprisePlanAdmin do
  use Plausible.Repo

  @numeric_fields [
    "team_id",
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
      team_id: nil,
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
      inner_join: o in assoc(t, :owners),
      or_where: ilike(r.paddle_plan_id, ^search_term),
      or_where: ilike(o.email, ^search_term),
      or_where: ilike(o.name, ^search_term),
      or_where: ilike(t.name, ^search_term),
      preload: [team: {t, owners: o}]
    )
  end

  def index(_) do
    [
      id: nil,
      user_email: %{value: &owner_emails(&1.team)},
      paddle_plan_id: nil,
      billing_interval: nil,
      monthly_pageview_limit: nil,
      site_limit: nil,
      team_member_limit: nil,
      hourly_api_request_limit: nil
    ]
  end

  defp owner_emails(team) do
    team.owners
    |> Enum.map_join("<br>", & &1.email)
    |> Phoenix.HTML.raw()
  end

  def create_changeset(schema, attrs) do
    attrs = sanitize_attrs(attrs)

    Plausible.Billing.EnterprisePlan.changeset(struct(schema, site_limit: 10_000), attrs)
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
