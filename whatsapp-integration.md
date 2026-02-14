## Complete Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         YOUR PHOENIX APPLICATION                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │  LiveView   │───▶│  WhatsApp   │───▶│   Meta      │◀───│  Webhook    │  │
│  │  Connect UI │    │  Context    │    │   Client    │    │  Controller │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│        │                  │                  │                  │          │
│        │                  │                  │                  │          │
│        ▼                  ▼                  │                  │          │
│  ┌─────────────┐    ┌─────────────┐         │                  │          │
│  │  JS Hook    │    │  Token      │         │                  │          │
│  │  (FB SDK)   │    │  Refresher  │         │                  │          │
│  └─────────────┘    │  (Oban)     │         │                  │          │
│                     └─────────────┘         │                  │          │
│                                             │                  │          │
└─────────────────────────────────────────────┼──────────────────┼──────────┘
                                              │                  │
                                              ▼                  │
┌─────────────────────────────────────────────────────────────────────────────┐
│                           META GRAPH API                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │   OAuth     │    │   WABA      │    │   Cloud     │    │  Webhooks   │  │
│  │   Token     │    │   Mgmt API  │    │   API       │    │  (messages) │  │
│  │   Exchange  │    │             │    │  (send/recv)│    │             │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                              │
                                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         WHATSAPP SERVERS                                    │
│                    (Message delivery to end users)                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Embedded Signup Flow with SUAT

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  Tenant  │     │ LiveView │     │  Phoenix │     │   Meta   │     │ Customer │
│  Browser │     │ + JS Hook│     │  Backend │     │  Graph   │     │ Business │
└────┬─────┘     └────┬─────┘     └────┬─────┘     └────┬─────┘     └────┬─────┘
     │                │                │                │                │
     │ 1. Click       │                │                │                │
     │ "Connect WA"   │                │                │                │
     │───────────────▶│                │                │                │
     │                │                │                │                │
     │                │ 2. push_event  │                │                │
     │                │ "start_fb_login"                │                │
     │◀───────────────│                │                │                │
     │                │                │                │                │
     │ 3. FB.login()  │                │                │                │
     │ (JS SDK)       │                │                │                │
     │─────────────────────────────────────────────────▶│                │
     │                │                │                │                │
     │ 4. OAuth popup │                │                │                │
     │    - FB Login  │                │                │                │
     │    - Select/Create Business     │                │                │
     │    - Select/Create WABA         │                │                │
     │    - Grant permissions          │                │                │
     │◀────────────────────────────────────────────────▶│◀──────────────▶│
     │                │                │                │                │
     │ 5. Return CODE │                │                │                │
     │ (authResponse) │                │                │                │
     │◀────────────────────────────────────────────────│                │
     │                │                │                │                │
     │ 6. push_event  │                │                │                │
     │ "fb_auth_code" │                │                │                │
     │───────────────▶│                │                │                │
     │                │                │                │                │
     │                │ 7. handle_event│                │                │
     │                │───────────────▶│                │                │
     │                │                │                │                │
     │                │                │ 8. Exchange    │                │
     │                │                │ CODE → SUAT    │                │
     │                │                │───────────────▶│                │
     │                │                │                │                │
     │                │                │ POST /oauth/access_token        │
     │                │                │ client_id, client_secret, code  │
     │                │                │                │                │
     │                │                │ 9. Return SUAT │                │
     │                │                │ (60 day token) │                │
     │                │                │◀───────────────│                │
     │                │                │                │                │
     │                │                │ 10. debug_token│                │
     │                │                │ (get WABA IDs) │                │
     │                │                │───────────────▶│                │
     │                │                │◀───────────────│                │
     │                │                │                │                │
     │                │                │ 11. Get phone  │                │
     │                │                │ numbers        │                │
     │                │                │───────────────▶│                │
     │                │                │◀───────────────│                │
     │                │                │                │                │
     │                │                │ 12. Subscribe  │                │
     │                │                │ to webhooks    │                │
     │                │                │───────────────▶│                │
     │                │                │◀───────────────│                │
     │                │                │                │                │
     │                │                │ 13. Save       │                │
     │                │                │ connection     │                │
     │                │                │ (encrypt SUAT!)│                │
     │                │◀───────────────│                │                │
     │                │                │                │                │
     │ 14. "Connected!│                │                │                │
     │     Successfully"               │                │                │
     │◀───────────────│                │                │                │
```

---

## Token Lifecycle Management

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      SUAT TOKEN LIFECYCLE                                   │
└─────────────────────────────────────────────────────────────────────────────┘

    Day 0                    Day 50                   Day 60
      │                        │                        │
      ▼                        ▼                        ▼
┌───────────┐            ┌───────────┐            ┌───────────┐
│   Token   │            │  Refresh  │            │  Token    │
│  Created  │───────────▶│  Window   │───────────▶│  Expires  │
│           │            │  (10 days)│            │           │
└───────────┘            └───────────┘            └───────────┘
                               │
                               │ Oban job triggers
                               ▼
                    ┌─────────────────────┐
                    │  Exchange for new   │
                    │  long-lived token   │
                    │                     │
                    │  POST /oauth/       │
                    │  access_token       │
                    │  ?grant_type=       │
                    │  fb_exchange_token  │
                    └─────────────────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │  Update DB with     │
                    │  new token +        │
                    │  new expiry date    │
                    └─────────────────────┘


Token Refresh Strategy:
───────────────────────
┌─────────────────────────────────────────────────────────────────────────────┐
│  Oban Worker: MyApp.Workers.RefreshWhatsAppTokens                          │
│  Schedule: Daily at 3 AM                                                    │
│                                                                             │
│  1. Query connections WHERE token_expires_at < NOW() + INTERVAL '10 days'  │
│  2. For each connection:                                                    │
│     a. Call Meta token exchange endpoint                                    │
│     b. Update token + expiry in DB                                          │
│     c. If refresh fails:                                                    │
│        - Mark connection as needs_reauth                                    │
│        - Send notification to tenant                                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Database Schema

```sql
CREATE TABLE whatsapp_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,

    -- Meta identifiers
    waba_id VARCHAR(50) NOT NULL,           -- WhatsApp Business Account ID
    phone_number_id VARCHAR(50),            -- Phone number ID (may be added later)
    phone_number VARCHAR(20),               -- E.164 format: +1234567890
    display_name VARCHAR(100),              -- Business display name

    -- SUAT Token (ENCRYPTED!)
    access_token_encrypted BYTEA NOT NULL,
    token_expires_at TIMESTAMPTZ NOT NULL,  -- Track 60-day expiry

    -- Webhook verification
    webhook_verify_token VARCHAR(64) NOT NULL,

    -- Status tracking
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    -- pending: signup started, not complete
    -- phone_required: WABA connected, needs phone number
    -- verifying: phone number verification in progress
    -- active: fully operational
    -- needs_reauth: token refresh failed
    -- suspended: Meta suspended (quality/policy)
    -- disconnected: user disconnected

    -- Meta quality info
    quality_rating VARCHAR(20),             -- GREEN, YELLOW, RED
    messaging_limit VARCHAR(20),            -- TIER_250, TIER_1K, TIER_10K, etc.

    -- Timestamps
    connected_at TIMESTAMPTZ,
    last_webhook_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    UNIQUE(tenant_id, waba_id),
    UNIQUE(phone_number_id)
);

CREATE INDEX idx_wa_conn_tenant ON whatsapp_connections(tenant_id);
CREATE INDEX idx_wa_conn_status ON whatsapp_connections(status);
CREATE INDEX idx_wa_conn_token_expiry ON whatsapp_connections(token_expires_at);

-- Phone numbers (a WABA can have multiple)
CREATE TABLE whatsapp_phone_numbers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    connection_id UUID NOT NULL REFERENCES whatsapp_connections(id) ON DELETE CASCADE,

    phone_number_id VARCHAR(50) NOT NULL,   -- Meta's phone number ID
    phone_number VARCHAR(20) NOT NULL,      -- E.164 format
    display_name VARCHAR(100),
    verified BOOLEAN DEFAULT FALSE,

    quality_rating VARCHAR(20),
    status VARCHAR(20) DEFAULT 'pending',   -- pending, verified, active, flagged

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(phone_number_id)
);
```

---

## Phoenix Implementation

### 1. Config

```elixir
# config/config.exs
config :my_app, :whatsapp,
  app_id: System.get_env("META_APP_ID"),
  app_secret: System.get_env("META_APP_SECRET"),
  config_id: System.get_env("META_CONFIG_ID"),  # FB Login for Business config
  graph_api_version: "v21.0",
  webhook_verify_token: System.get_env("WHATSAPP_WEBHOOK_VERIFY_TOKEN")
```

### 2. LiveView

```elixir
defmodule MyAppWeb.WhatsApp.ConnectLive do
  use MyAppWeb, :live_view

  alias MyApp.WhatsApp

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_tenant

    {:ok,
     socket
     |> assign(:tenant_id, tenant.id)
     |> assign(:connections, WhatsApp.list_connections(tenant.id))
     |> assign(:connecting, false)
     |> assign(:error, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-6">
      <h1 class="text-2xl font-bold mb-6">WhatsApp Integration</h1>

      <.error_alert :if={@error} message={@error} />

      <!-- Existing Connections -->
      <div :if={@connections != []} class="mb-8 space-y-4">
        <.connection_card :for={conn <- @connections} connection={conn} />
      </div>

      <!-- Connect Button -->
      <div class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center">
        <button
          id="wa-connect-btn"
          phx-click="init_connect"
          phx-hook="WhatsAppEmbeddedSignup"
          disabled={@connecting}
          data-app-id={whatsapp_config(:app_id)}
          data-config-id={whatsapp_config(:config_id)}
          data-api-version={whatsapp_config(:graph_api_version)}
          class="bg-green-500 hover:bg-green-600 text-white px-6 py-3 rounded-lg font-medium disabled:opacity-50"
        >
          <%= if @connecting, do: "Connecting...", else: "Connect WhatsApp" %>
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("init_connect", _params, socket) do
    {:noreply,
     socket
     |> assign(:connecting, true)
     |> push_event("start_fb_login", %{})}
  end

  @impl true
  def handle_event("fb_auth_success", %{"code" => code}, socket) do
    tenant_id = socket.assigns.tenant_id

    case WhatsApp.complete_embedded_signup(tenant_id, code) do
      {:ok, connection} ->
        {:noreply,
         socket
         |> assign(:connecting, false)
         |> assign(:connections, [connection | socket.assigns.connections])
         |> put_flash(:info, "WhatsApp connected successfully!")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:connecting, false)
         |> assign(:error, format_error(reason))}
    end
  end

  @impl true
  def handle_event("fb_auth_cancelled", _params, socket) do
    {:noreply,
     socket
     |> assign(:connecting, false)
     |> assign(:error, "Connection cancelled")}
  end

  defp whatsapp_config(key) do
    Application.get_env(:my_app, :whatsapp)[key]
  end
end
```

### 3. JavaScript Hook

```javascript
// assets/js/hooks/whatsapp_embedded_signup.js
export const WhatsAppEmbeddedSignup = {
  mounted() {
    this.appId = this.el.dataset.appId
    this.configId = this.el.dataset.configId
    this.apiVersion = this.el.dataset.apiVersion

    this.loadFacebookSDK()

    this.handleEvent("start_fb_login", () => {
      this.launchEmbeddedSignup()
    })
  },

  loadFacebookSDK() {
    if (window.FB) return

    window.fbAsyncInit = () => {
      FB.init({
        appId: this.appId,
        cookie: true,
        xfbml: true,
        version: this.apiVersion
      })
    }

    const script = document.createElement('script')
    script.src = 'https://connect.facebook.net/en_US/sdk.js'
    script.async = true
    script.defer = true
    document.body.appendChild(script)
  },

  launchEmbeddedSignup() {
    // Optional: conversion tracking
    if (window.fbq) {
      fbq('trackCustom', 'WhatsAppOnboardingStart', {
        appId: this.appId,
        feature: 'whatsapp_embedded_signup'
      })
    }

    FB.login(
      (response) => {
        if (response.authResponse?.code) {
          this.pushEvent("fb_auth_success", {
            code: response.authResponse.code
          })
        } else {
          this.pushEvent("fb_auth_cancelled", {})
        }
      },
      {
        config_id: this.configId,
        response_type: 'code',           // Required for SUAT
        override_default_response_type: true,
        extras: {
          feature: 'whatsapp_embedded_signup',
          version: 2,
          sessionInfoVersion: 2,
          // Optional: skip phone selection if you want to handle it yourself
          // featureType: 'only_waba_sharing'
        }
      }
    )
  }
}
```

### 4. WhatsApp Context

```elixir
defmodule MyApp.WhatsApp do
  alias MyApp.Repo
  alias MyApp.WhatsApp.{Connection, MetaClient}

  def complete_embedded_signup(tenant_id, auth_code) do
    with {:ok, token_data} <- MetaClient.exchange_code_for_token(auth_code),
         {:ok, debug_info} <- MetaClient.debug_token(token_data.access_token),
         {:ok, waba_id} <- extract_waba_id(debug_info),
         {:ok, phone_numbers} <- MetaClient.get_phone_numbers(waba_id, token_data.access_token),
         :ok <- MetaClient.subscribe_to_webhooks(waba_id, token_data.access_token) do

      create_connection(%{
        tenant_id: tenant_id,
        waba_id: waba_id,
        access_token: token_data.access_token,
        token_expires_at: token_data.expires_at,
        phone_numbers: phone_numbers,
        status: if(Enum.empty?(phone_numbers), do: "phone_required", else: "active")
      })
    end
  end

  defp extract_waba_id(%{"data" => %{"granular_scopes" => scopes}}) do
    scope = Enum.find(scopes, &(&1["scope"] == "whatsapp_business_management"))

    case scope["target_ids"] do
      [waba_id | _] -> {:ok, waba_id}
      _ -> {:error, :no_waba_found}
    end
  end

  defp create_connection(attrs) do
    %Connection{}
    |> Connection.changeset(attrs)
    |> Repo.insert()
  end
end
```

### 5. Meta API Client

```elixir
defmodule MyApp.WhatsApp.MetaClient do
  @graph_url "https://graph.facebook.com"

  def exchange_code_for_token(code) do
    config = Application.get_env(:my_app, :whatsapp)

    params = %{
      client_id: config[:app_id],
      client_secret: config[:app_secret],
      code: code
    }

    case Req.get("#{@graph_url}/#{config[:graph_api_version]}/oauth/access_token",
           params: params
         ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, %{
          access_token: body["access_token"],
          expires_at: DateTime.add(DateTime.utc_now(), body["expires_in"], :second)
        }}

      {:ok, %{body: %{"error" => error}}} ->
        {:error, error}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def debug_token(access_token) do
    config = Application.get_env(:my_app, :whatsapp)

    Req.get("#{@graph_url}/#{config[:graph_api_version]}/debug_token",
      params: %{input_token: access_token},
      headers: [{"authorization", "Bearer #{access_token}"}]
    )
    |> handle_response()
  end

  def get_phone_numbers(waba_id, access_token) do
    config = Application.get_env(:my_app, :whatsapp)

    Req.get("#{@graph_url}/#{config[:graph_api_version]}/#{waba_id}/phone_numbers",
      headers: [{"authorization", "Bearer #{access_token}"}]
    )
    |> handle_response()
    |> case do
      {:ok, %{"data" => phones}} -> {:ok, phones}
      error -> error
    end
  end

  def subscribe_to_webhooks(waba_id, access_token) do
    config = Application.get_env(:my_app, :whatsapp)

    Req.post("#{@graph_url}/#{config[:graph_api_version]}/#{waba_id}/subscribed_apps",
      headers: [{"authorization", "Bearer #{access_token}"}]
    )
    |> handle_response()
    |> case do
      {:ok, %{"success" => true}} -> :ok
      error -> error
    end
  end

  def refresh_token(current_token) do
    config = Application.get_env(:my_app, :whatsapp)

    params = %{
      grant_type: "fb_exchange_token",
      client_id: config[:app_id],
      client_secret: config[:app_secret],
      fb_exchange_token: current_token
    }

    Req.get("#{@graph_url}/#{config[:graph_api_version]}/oauth/access_token",
      params: params
    )
    |> handle_response()
  end

  defp handle_response({:ok, %{status: 200, body: body}}), do: {:ok, body}
  defp handle_response({:ok, %{body: %{"error" => error}}}), do: {:error, error}
  defp handle_response({:error, reason}), do: {:error, reason}
end
```

### 6. Token Refresh Worker (Oban)

```elixir
defmodule MyApp.Workers.RefreshWhatsAppTokens do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias MyApp.{Repo, WhatsApp}
  alias MyApp.WhatsApp.{Connection, MetaClient}
  import Ecto.Query

  @refresh_threshold_days 10

  @impl Oban.Worker
  def perform(_job) do
    threshold = DateTime.add(DateTime.utc_now(), @refresh_threshold_days, :day)

    Connection
    |> where([c], c.token_expires_at < ^threshold)
    |> where([c], c.status == "active")
    |> Repo.all()
    |> Enum.each(&refresh_connection/1)

    :ok
  end

  defp refresh_connection(connection) do
    token = WhatsApp.decrypt_token(connection.access_token_encrypted)

    case MetaClient.refresh_token(token) do
      {:ok, %{"access_token" => new_token, "expires_in" => expires_in}} ->
        connection
        |> Connection.changeset(%{
          access_token: new_token,
          token_expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second)
        })
        |> Repo.update()

      {:error, _reason} ->
        connection
        |> Connection.changeset(%{status: "needs_reauth"})
        |> Repo.update()

        # Notify tenant
        MyApp.Notifications.send(
          connection.tenant_id,
          :whatsapp_reauth_required,
          %{connection_id: connection.id}
        )
    end
  end
end
```

### 7. Webhook Controller

```elixir
defmodule MyAppWeb.WhatsAppWebhookController do
  use MyAppWeb, :controller

  alias MyApp.WhatsApp

  # GET - Webhook verification
  def verify(conn, params) do
    verify_token = Application.get_env(:my_app, :whatsapp)[:webhook_verify_token]

    case params do
      %{
        "hub.mode" => "subscribe",
        "hub.verify_token" => ^verify_token,
        "hub.challenge" => challenge
      } ->
        send_resp(conn, 200, challenge)

      _ ->
        send_resp(conn, 403, "Forbidden")
    end
  end

  # POST - Receive webhooks
  def webhook(conn, %{"object" => "whatsapp_business_account", "entry" => entries}) do
    # Always respond 200 immediately
    send_resp(conn, 200, "OK")

    # Process async
    Task.Supervisor.start_child(MyApp.TaskSupervisor, fn ->
      Enum.each(entries, &process_entry/1)
    end)
  end

  def webhook(conn, _params) do
    send_resp(conn, 200, "OK")
  end

  defp process_entry(%{"id" => waba_id, "changes" => changes}) do
    Enum.each(changes, fn change ->
      case change["field"] do
        "messages" -> WhatsApp.process_messages(waba_id, change["value"])
        "message_template_status_update" -> WhatsApp.process_template_update(waba_id, change["value"])
        "account_update" -> WhatsApp.process_account_update(waba_id, change["value"])
        _ -> :ignore
      end
    end)
  end
end
```

---

## Meta App Configuration Checklist

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    META DEVELOPER PORTAL SETUP                              │
└─────────────────────────────────────────────────────────────────────────────┘

1. CREATE META APP
   ─────────────────
   □ Go to developers.facebook.com
   □ Create App → Type: Business
   □ Add WhatsApp product
   □ Add Facebook Login for Business product

2. FACEBOOK LOGIN FOR BUSINESS CONFIGURATION
   ──────────────────────────────────────────
   □ Go to: Facebook Login for Business → Settings
   □ Enable:
     ✓ Client OAuth login
     ✓ Web OAuth login
     ✓ Enforce HTTPS
     ✓ Embedded Browser OAuth Login
     ✓ Use Strict Mode for redirect URIs
     ✓ Login with the JavaScript SDK
   □ Add your domain to "Allowed Domains for the JavaScript SDK"

3. CREATE LOGIN CONFIGURATION
   ───────────────────────────
   □ Go to: Facebook Login for Business → Configurations
   □ Click "Create Configuration"
   □ Name: "WhatsApp Embedded Signup" (internal, users don't see)
   □ Login variation: "WhatsApp Embedded Signup"
   □ Access token: "System-user access token"
   □ Token expiration: 60 days (default)
   □ Assets: Select "WhatsApp accounts"
   □ Permissions:
     ✓ whatsapp_business_management
     ✓ whatsapp_business_messaging
   □ Save and copy the CONFIG_ID

4. WEBHOOK CONFIGURATION
   ──────────────────────
   □ Go to: WhatsApp → Configuration
   □ Callback URL: https://yourdomain.com/api/webhooks/whatsapp
   □ Verify token: (generate random string, store in env)
   □ Subscribe to fields:
     ✓ messages
     ✓ message_template_status_update
     ✓ account_update (optional)

5. APP REVIEW (for production)
   ────────────────────────────
   □ Submit for review:
     ✓ whatsapp_business_management
     ✓ whatsapp_business_messaging
   □ Provide use case documentation
   □ Wait for approval (usually 1-5 business days)
```

---

## Summary

| Aspect | Your Implementation |
|--------|---------------------|
| **Token Type** | System User Access Token (SUAT) |
| **Token Expiry** | 60 days (auto-refresh at day 50) |
| **Signup Flow** | Embedded Signup via FB JS SDK |
| **Who creates WABA?** | Customer (during embedded signup) |
| **Phone Numbers** | Customer adds via embedded signup or your UI |
| **Webhooks** | Single endpoint for all tenants, route by WABA ID |
| **Token Storage** | Encrypted in DB (use Cloak or similar) |
| **Refresh Strategy** | Oban job runs daily, refreshes tokens expiring in <10 days |
