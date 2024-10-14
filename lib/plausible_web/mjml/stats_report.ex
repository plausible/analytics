defmodule PlausibleWeb.MJML.StatsReport do
  @moduledoc """
  MJML rendered for the weekly or monthly report e-mail
  """

  use MjmlEEx, mjml_template: "templates/stats_report.mjml.eex"
end
