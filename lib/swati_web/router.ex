defmodule SwatiWeb.Router do
  use SwatiWeb, :router

  import SwatiWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SwatiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug SwatiWeb.Plugs.FetchCurrentTenant
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :internal do
    plug :accepts, ["json"]
    plug SwatiWeb.Plugs.VerifyInternalToken
  end

  scope "/", SwatiWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/api/v1", SwatiWeb do
    pipe_through :api
  end

  scope "/internal/v1", SwatiWeb.Internal do
    pipe_through :internal

    get "/runtime/phone_numbers/:phone_number", RuntimeController, :show
    post "/calls/start", CallsController, :start
    post "/calls/:call_id/events", CallsController, :events
    post "/calls/:call_id/end", CallsController, :end_call
    post "/calls/:call_id/artifacts", CallsController, :artifacts
    post "/calls/:call_id/timeline", CallsController, :timeline
  end

  # Other scopes may use custom stacks.
  # scope "/api", SwatiWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:swati, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/metrics", metrics: SwatiWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", SwatiWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{SwatiWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/settings/members", TenantLive.Members, :index

      live "/onboarding", OnboardingLive, :index
      live "/dashboard", DashboardLive.Index, :index
      live "/agents", AgentsLive.Index, :index
      live "/agents/new", AgentsLive.Form, :new
      live "/agents/:id/edit", AgentsLive.Form, :edit
      live "/agents/:id/versions", AgentsLive.Versions, :index
      live "/agent-data", AgentDataLive.Index, :index
      live "/integrations/new", AgentDataLive.Index, :new_integration
      live "/integrations/:id/edit", IntegrationsLive.Form, :edit
      live "/integrations/:id", IntegrationsLive.Show, :show
      live "/webhooks/new", AgentDataLive.Index, :new_webhook
      live "/webhooks/:id/edit", AgentDataLive.Index, :edit_webhook
      live "/webhooks/:id", WebhooksLive.Show, :show
      live "/numbers", PhoneNumbersLive.Index, :index
      live "/calls", CallsLive.Index, :index
      live "/calls/:id", CallsLive.Index, :show
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", SwatiWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{SwatiWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
