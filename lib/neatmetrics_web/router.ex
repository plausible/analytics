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
    get "/:website", PageController, :analytics
  end

   scope "/api", NeatmetricsWeb do
     pipe_through :external_api

     post "/page", ApiController, :page
   end
end
