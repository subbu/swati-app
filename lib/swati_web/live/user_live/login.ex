defmodule SwatiWeb.UserLive.Login do
  use SwatiWeb, :live_view

  alias Swati.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <% error_message = Phoenix.Flash.get(@flash, :error) %>

      <div class="flex flex-1 flex-col items-center justify-center py-6 gap-y-6 min-h-svh">
        <div class="overflow-hidden relative w-full max-w-md border border-base rounded-base shadow-base bg-base p-10">
          <div class="absolute -top-0 -translate-y-1/2 inset-x-0 h-[350px] pointer-events-none">
            <svg width="100%" height="100%" xmlns="http://www.w3.org/2000/svg">
              <defs>
                <pattern
                  id="grid-pattern"
                  x="0"
                  y="0"
                  width="48"
                  height="48"
                  patternUnits="userSpaceOnUse"
                >
                  <g fill="none" opacity="0.1">
                    <path d="M48 23.5L0 23.5" stroke="currentColor"></path>
                    <path d="M48 47.5001L0 47.5001" stroke="currentColor"></path>
                    <path d="M23.5 0V48" stroke="currentColor"></path>
                    <path d="M47.5 0V48" stroke="currentColor"></path>
                  </g>
                  <g opacity="0.035">
                    <rect width="24" height="24" fill="currentColor"></rect>
                    <rect x="24" y="24" width="24" height="24" fill="currentColor"></rect>
                  </g>
                </pattern>

                <radialGradient id="fade-gradient" cx="50%" cy="50%" r="50%" fx="50%" fy="50%">
                  <stop offset="0%" stop-color="white" stop-opacity="1"></stop>
                  <stop offset="50%" stop-color="white" stop-opacity="0.7"></stop>
                  <stop offset="100%" stop-color="white" stop-opacity="0.1"></stop>
                </radialGradient>

                <mask id="fade-mask">
                  <rect width="100%" height="100%" fill="url(#fade-gradient)"></rect>
                </mask>
              </defs>

              <rect width="100%" height="100%" fill="url(#grid-pattern)" mask="url(#fade-mask)">
              </rect>
            </svg>
          </div>

          <div class="relative z-10">
            <div class="flex items-center justify-center mb-4">
              <img src={~p"/images/swati_logo.png"} alt="Swati AI" class="h-12" />
            </div>

            <h1 class="text-center text-2xl/10 font-bold text-foreground">Welcome back</h1>
            <p class="text-center text-sm text-foreground-softer">
              <%= if @current_scope do %>
                Reauthenticate to continue managing your account.
              <% else %>
                Sign in to continue.
              <% end %>
            </p>

            <.alert
              :if={local_mail_adapter?()}
              color="info"
              title="Local mail adapter"
              class="mt-6"
            >
              To see sent emails, visit <.link href="/dev/mailbox" class="underline">the mailbox page</.link>.
            </.alert>

            <.form
              for={@form_magic}
              id="login_form_magic"
              action={~p"/users/log-in"}
              phx-submit="submit_magic"
              class="flex flex-col gap-y-6 mt-6"
            >
              <.input
                readonly={!!@current_scope}
                field={@form_magic[:email]}
                type="email"
                label="Email"
                placeholder="Enter your email..."
                autocomplete="email"
                required
                phx-mounted={JS.focus()}
              />
              <.button type="submit" variant="solid" class="w-full" size="lg">
                Send magic link
              </.button>
            </.form>

            <.separator text="OR" class="my-6" />

            <.form
              for={@form_password}
              id="login_form_password"
              action={~p"/users/log-in"}
              phx-submit="submit_password"
              phx-trigger-action={@trigger_submit}
              class="flex flex-col gap-y-6"
            >
              <.alert :if={error_message} color="danger" title={error_message} />
              <.input
                readonly={!!@current_scope}
                field={@form_password[:email]}
                type="email"
                label="Email"
                placeholder="Enter your email..."
                autocomplete="email"
                required
              />
              <.input
                field={@form_password[:password]}
                type="password"
                label="Password"
                placeholder="********"
                autocomplete="current-password"
              />
              <div class="flex items-center justify-between">
                <.checkbox field={@form_password[:remember_me]} label="Remember me" />
              </div>
              <.button
                type="submit"
                variant="solid"
                phx-disable-with="Signing in..."
                class="w-full"
                size="lg"
              >
                Sign in
              </.button>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form_params = %{"email" => email}

    form_magic = to_form(form_params, as: "user", id: "login_form_magic")
    form_password = to_form(form_params, as: "user", id: "login_form_password")

    {:ok,
     assign(socket,
       form_magic: form_magic,
       form_password: form_password,
       trigger_submit: false
     )}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:swati, Swati.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
