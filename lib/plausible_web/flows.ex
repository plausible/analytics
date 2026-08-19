defmodule PlausibleWeb.Flows do
  @moduledoc """
  Named identifiers and documentation for the onboarding/installation flows.
  """

  @doc """
  The flow of creating a new account from scratch:

  * Register form
  * Activate account (email confirmation)
  * ...optional onboarding steps (see `onboarding_steps/0`)
  * End up either on the dashboard (with verification kicked off automatically)
    or the /sites page, depending on whether a site was setup or not.
  """
  def register, do: "register"

  @doc """
  The flow of an already logged in user adding another site to their team:

  * Add site info
  * Installation screen
  * End up either on the dashboard (with verification kicked off automatically)
    or the /sites page, depending on whether installation was skipped or not
  """
  def provisioning, do: "provisioning"

  @doc """
  The flow of an existing user reviewing/re-checking their already-installed
  tracking script (triggered from site settings):

  * Installation screen, pre-filled with the earlier installation method
  * End up on the dashboard (with verification kicked off automatically)
  """
  def review, do: "review"

  @doc """
  The flow of an existing site domain getting changed (triggered from
  site settings):

  * Domain name change form
  * Domain change success info page (possible further actions required)
  * Back to site settings
  """
  def domain_change, do: "domain_change"

  @doc """
  The flow of accepting a team/site invitation as a new user:

  * Register form
  * Activate account (email confirmation)
  * Land on the /sites page
  """
  def invitation, do: "invitation"

  @doc """
  The steps shown in the onboarding flow's progress indicator.
  """
  def onboarding_steps, do: [add_site_step(), installation_step()]

  def add_site_step, do: "Add site info"
  def installation_step, do: "Install Plausible"
end
