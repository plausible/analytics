defmodule NeatmetricsWeb.Router do
  use NeatmetricsWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :external_api do
    plug :accepts, ["text/plain"]
  end

  pipeline :api do
    plug :accepts, ["application/json"]
  end

  scope "/", NeatmetricsWeb do
    pipe_through :browser

    get "/", PageController, :index
    get "/onboarding", PageController, :onboarding
    post "/onboarding/site", PageController, :create_site
    post "/login", PageController, :send_login_link
    get "/claim-login", PageController, :claim_login_link
    get "/login", PageController, :login_form
    get "/:website", PageController, :analytics
    post "/logout", PageController, :logout
  end

   scope "/api", NeatmetricsWeb do
     pipe_through :external_api

     post "/page", ApiController, :page
   end
end
