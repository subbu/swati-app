defmodule SwatiWeb.BillingLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Accounts
  alias Swati.Billing
  alias Swati.Billing.Entitlements
  alias SwatiWeb.Formatting

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-10">
        <div class="space-y-1">
          <h1 class="text-2xl font-semibold">Billing</h1>
          <p class="text-sm text-base-content/70">
            Manage your plan, usage, and subscription status.
          </p>
        </div>

        <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
          <div class="flex flex-wrap items-start justify-between gap-4">
            <div class="space-y-1">
              <h2 class="text-lg font-semibold">Current plan</h2>
              <p class="text-sm text-base-content/70">
                {plan_label(@current_plan)}
              </p>
              <p class="text-sm font-medium text-base-content/80">
                {plan_price_label(@current_plan)}
              </p>
            </div>

            <.badge color={status_color(@subscription)} variant="soft">
              {status_label(@subscription)}
            </.badge>
          </div>

          <div class="grid gap-4 md:grid-cols-3">
            <div class="rounded-xl border border-base-200 bg-base-50 p-4">
              <p class="text-xs uppercase tracking-wide text-base-content/60">Billing period</p>
              <p class="text-sm font-medium">
                {format_date(@usage_cycle, @current_scope.tenant)}
              </p>
            </div>
            <div class="rounded-xl border border-base-200 bg-base-50 p-4">
              <p class="text-xs uppercase tracking-wide text-base-content/60">Next charge</p>
              <p class="text-sm font-medium">
                {format_date(@subscription && @subscription.next_charge_at, @current_scope.tenant)}
              </p>
            </div>
            <div class="rounded-xl border border-base-200 bg-base-50 p-4">
              <p class="text-xs uppercase tracking-wide text-base-content/60">Subscription ID</p>
              <p class="text-sm font-medium break-all">
                {(@subscription && @subscription.provider_subscription_id) || "—"}
              </p>
            </div>
          </div>

          <%= if @pending_plan do %>
            <div class="rounded-xl border border-primary/20 bg-primary/5 p-4 text-sm text-base-content/80">
              Plan change scheduled to {plan_label(@pending_plan)}.
              Effective {format_date(
                @subscription && @subscription.current_end_at,
                @current_scope.tenant
              )}.
            </div>
          <% end %>

          <%= if @upcoming_subscription do %>
            <div class="rounded-xl border border-warning/20 bg-warning/5 p-4 text-sm text-base-content/80 space-y-2">
              <div>
                Upcoming subscription starts {format_date(
                  @upcoming_subscription.current_start_at,
                  @current_scope.tenant
                )}.
              </div>
              <%= if @upcoming_payment_link do %>
                <.link
                  href={@upcoming_payment_link}
                  target="_blank"
                  class="font-semibold underline text-warning"
                >
                  Complete payment to activate
                </.link>
              <% end %>
            </div>
          <% end %>
        </section>

        <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
          <div>
            <h2 class="text-lg font-semibold">Usage</h2>
            <p class="text-sm text-base-content/70">
              Tracked for the current billing period.
            </p>
          </div>

          <div class="grid gap-4 md:grid-cols-3">
            <div class="rounded-xl border border-base-200 bg-base-50 p-4 space-y-1">
              <p class="text-xs uppercase tracking-wide text-base-content/60">Phone numbers</p>
              <p class="text-sm font-medium">
                {usage_value(@usage_counters, "phone_numbers_current")} / {entitlement_value(
                  @entitlements,
                  "max_phone_numbers"
                )}
              </p>
            </div>
            <div class="rounded-xl border border-base-200 bg-base-50 p-4 space-y-1">
              <p class="text-xs uppercase tracking-wide text-base-content/60">Integrations</p>
              <p class="text-sm font-medium">
                {usage_value(@usage_counters, "integrations_current")} / {entitlement_value(
                  @entitlements,
                  "max_integrations"
                )}
              </p>
            </div>
            <div class="rounded-xl border border-base-200 bg-base-50 p-4 space-y-1">
              <p class="text-xs uppercase tracking-wide text-base-content/60">Call minutes</p>
              <p class="text-sm font-medium">
                {usage_value(@usage_counters, "call_minutes_used")} / {entitlement_value(
                  @entitlements,
                  "included_call_minutes"
                )}
              </p>
              <p class="text-xs text-base-content/60">
                Overage: {usage_value(@usage_counters, "call_minutes_overage")}
              </p>
            </div>
          </div>
        </section>

        <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
          <div>
            <h2 class="text-lg font-semibold">Manage subscription</h2>
            <p class="text-sm text-base-content/70">
              Choose how and when plan changes apply.
            </p>
          </div>

          <%= if @upi_restricted? do %>
            <div class="rounded-xl border border-warning/30 bg-warning/10 p-4 text-sm text-base-content/80">
              UPI subscriptions can’t be updated in-place. Cancel at cycle end, then pay again to
              switch plans.
            </div>
          <% end %>

          <.form
            for={@plan_form}
            id="billing-plan-form"
            phx-submit="change_plan"
            phx-change="plan_change"
          >
            <div class="grid gap-4 md:grid-cols-[1.5fr_1fr_auto] items-end">
              <.select
                field={@plan_form[:plan_code]}
                label="Plan"
                options={@plan_options}
                native
                disabled={!@can_manage?}
              />
              <.select
                field={@plan_form[:timing]}
                label="When"
                options={@timing_options}
                native
                disabled={!@can_manage? or @upi_restricted?}
              />
              <.button
                id="billing-change-plan"
                class="btn btn-primary w-full md:w-auto"
                phx-disable-with="Updating..."
                disabled={!@can_manage? or @upi_restricted?}
              >
                Update plan
              </.button>
            </div>
          </.form>

          <%= if @pending_plan && @can_manage? && !@upi_restricted? do %>
            <div class="flex items-center justify-between gap-3 text-sm text-base-content/70">
              <span>Scheduled change is pending.</span>
              <.button
                id="billing-cancel-scheduled"
                class="btn btn-ghost"
                phx-click="cancel_scheduled_change"
                phx-disable-with="Cancelling..."
              >
                Cancel scheduled change
              </.button>
            </div>
          <% end %>

          <%= if (notice = cancellation_notice(@subscription, @current_scope.tenant)) do %>
            <%= case notice do %>
              <% {:danger, message} -> %>
                <.alert id="billing-cancel-notice" color="danger" hide_close>
                  {message}
                </.alert>
              <% {_level, message} -> %>
                <div
                  id="billing-cancel-notice"
                  class="rounded-xl border border-base-200 bg-base-50 p-3 text-sm text-base-content/80"
                >
                  {message}
                </div>
            <% end %>
          <% else %>
            <div id="billing-cancel-row" class="flex flex-wrap items-center justify-between gap-4">
              <div class="text-sm text-base-content/70">
                Cancel at the end of the current billing cycle.
              </div>
              <.button
                id="billing-cancel"
                class="btn btn-outline"
                phx-click="cancel_subscription"
                phx-disable-with="Cancelling..."
                disabled={!@can_manage? or cancel_disabled?(@subscription)}
              >
                Cancel subscription
              </.button>
            </div>
          <% end %>

          <%= if @plan_notice do %>
            <div class="rounded-xl border border-base-200 bg-base-50 p-3 text-sm text-base-content/80">
              {@plan_notice}
            </div>
          <% end %>

          <%= if @can_manage? && show_pay_again?(@subscription, @upi_restricted?) do %>
            <div class="rounded-xl border border-base-200 bg-base-50 p-4 space-y-2">
              <div class="text-sm font-medium">Pay again</div>
              <p class="text-xs text-base-content/70">
                Generates a new payment link for the selected plan.
              </p>
              <%= if pay_again_disabled?(@subscription, @upi_restricted?) do %>
                <p class="text-xs text-base-content/60">
                  UPI subscriptions require a fresh authorization after the current cycle. This
                  unlocks once your current cycle ends.
                </p>
              <% end %>
              <div class="flex flex-wrap items-center gap-3">
                <.button
                  id="billing-pay-again"
                  class="btn btn-secondary"
                  phx-click="pay_again"
                  phx-disable-with="Preparing link..."
                  disabled={!@can_manage? or pay_again_disabled?(@subscription, @upi_restricted?)}
                >
                  Pay again
                </.button>
                <%= if @payment_link || @upcoming_payment_link do %>
                  <.link
                    href={@payment_link || @upcoming_payment_link}
                    target="_blank"
                    class="text-sm font-semibold underline"
                  >
                    Open payment link
                  </.link>
                <% end %>
              </div>
            </div>
          <% end %>
        </section>

        <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
          <div>
            <h2 class="text-lg font-semibold">Invoices</h2>
            <p class="text-sm text-base-content/70">
              Latest invoices for this subscription.
            </p>
          </div>

          <%= if @invoice_error do %>
            <div class="rounded-xl border border-danger/20 bg-danger/5 p-4 text-sm">
              Unable to load invoices right now.
            </div>
          <% end %>

          <.table>
            <.table_head>
              <:col>Date</:col>
              <:col>Amount</:col>
              <:col>Status</:col>
              <:col>Invoice ID</:col>
            </.table_head>
            <.table_body id="billing-invoices" phx-update="stream">
              <.table_row id="invoices-empty" class="hidden only:table-row">
                <:cell colspan="4" class="text-sm text-base-content/70 text-center py-6">
                  No invoices yet.
                </:cell>
              </.table_row>

              <.table_row :for={{id, invoice} <- @streams.invoices} id={id}>
                <:cell class="text-sm">
                  {format_unix(invoice["date"], @current_scope.tenant)}
                </:cell>
                <:cell class="text-sm font-medium">
                  {format_amount(invoice["amount"], invoice["currency"])}
                </:cell>
                <:cell class="text-sm">
                  {invoice["status"] || "—"}
                </:cell>
                <:cell class="text-xs text-base-content/70 break-all">
                  {invoice["id"]}
                </:cell>
              </.table_row>
            </.table_body>
          </.table>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> stream_configure(:invoices, dom_id: &invoice_dom_id/1)
      |> assign(:page_title, "Billing")
      |> assign(:can_manage?, Accounts.authorized?(socket.assigns.current_scope, :manage_billing))
      |> assign(:plan_notice, nil)
      |> assign(:payment_link, nil)
      |> assign(:invoice_error, false)

    {:ok, load_billing(socket)}
  end

  @impl true
  def handle_event("plan_change", %{"plan" => params}, socket) do
    params =
      params
      |> Map.put_new("timing", "now")
      |> Map.put_new("plan_code", socket.assigns.current_scope.tenant.plan)

    {:noreply,
     socket
     |> assign(:plan_params, params)
     |> assign(:plan_form, to_form(params, as: :plan))}
  end

  @impl true
  def handle_event(
        "change_plan",
        %{"plan" => %{"plan_code" => plan_code, "timing" => timing}},
        socket
      ) do
    if socket.assigns.can_manage? do
      timing = if to_string(timing) == "cycle_end", do: :cycle_end, else: :now

      case Billing.change_plan(socket.assigns.current_scope.tenant, plan_code, timing) do
        {:ok, _body} ->
          message =
            if timing == :cycle_end do
              "Plan change scheduled for cycle end."
            else
              "Plan updated."
            end

          {:noreply,
           socket
           |> put_flash(:info, message)
           |> assign(:plan_notice, message)
           |> load_billing()}

        {:error, %Swati.Billing.Error{} = error} ->
          {:noreply, handle_billing_error(socket, error)}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Plan update failed.")}
      end
    else
      {:noreply, unauthorized(socket)}
    end
  end

  def handle_event("cancel_scheduled_change", _params, socket) do
    if socket.assigns.can_manage? do
      case Billing.cancel_scheduled_change(socket.assigns.current_scope.tenant) do
        {:ok, _body} ->
          {:noreply,
           socket
           |> put_flash(:info, "Scheduled change cancelled.")
           |> assign(:plan_notice, "Scheduled change cancelled.")
           |> load_billing()}

        {:error, %Swati.Billing.Error{} = error} ->
          {:noreply, handle_billing_error(socket, error)}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Unable to cancel scheduled change.")}
      end
    else
      {:noreply, unauthorized(socket)}
    end
  end

  def handle_event("cancel_subscription", _params, socket) do
    if socket.assigns.can_manage? do
      case Billing.cancel_subscription(socket.assigns.current_scope.tenant, true) do
        {:ok, _body} ->
          {:noreply,
           socket
           |> put_flash(:info, "Cancellation scheduled.")
           |> assign(:plan_notice, "Cancellation scheduled for cycle end.")
           |> load_billing()}

        {:error, %Swati.Billing.Error{} = error} ->
          {:noreply, handle_billing_error(socket, error)}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Cancellation failed.")}
      end
    else
      {:noreply, unauthorized(socket)}
    end
  end

  def handle_event("pay_again", _params, socket) do
    cond do
      not socket.assigns.can_manage? ->
        {:noreply, unauthorized(socket)}

      not show_pay_again?(socket.assigns.subscription, socket.assigns.upi_restricted?) ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Pay again is only available for UPI subscriptions that failed or expired."
         )}

      true ->
        plan_code = selected_plan_code(socket)

        case Billing.pay_again(socket.assigns.current_scope.tenant, plan_code) do
          {:ok, %{short_url: short_url}} ->
            {:noreply,
             socket
             |> assign(:payment_link, short_url)
             |> assign(:plan_notice, "Payment link ready.")
             |> load_billing()}

          {:error, %Swati.Billing.Error{} = error} ->
            {:noreply, handle_billing_error(socket, error)}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Unable to prepare payment.")}
        end
    end
  end

  defp load_billing(socket) do
    tenant = socket.assigns.current_scope.tenant
    subscription = Billing.subscription_for_tenant(tenant.id)
    upcoming_subscription = Billing.upcoming_subscription_for_tenant(tenant.id)
    usage = Billing.usage_summary(tenant.id)
    plans = Billing.list_plans()
    current_plan = Enum.find(plans, &(&1.code == tenant.plan))
    pending_plan = pending_plan(subscription, plans)

    plan_params =
      socket.assigns[:plan_params] || %{"plan_code" => tenant.plan, "timing" => "now"}

    plan_form = to_form(plan_params, as: :plan)

    {invoices, invoice_error} = load_invoices(subscription, socket)

    socket
    |> assign(:subscription, subscription)
    |> assign(:upcoming_subscription, upcoming_subscription)
    |> assign(:upcoming_payment_link, upcoming_payment_link(upcoming_subscription))
    |> assign(:usage_cycle, usage.cycle)
    |> assign(:usage_counters, usage.counters)
    |> assign(:entitlements, Entitlements.effective(tenant))
    |> assign(:plan_options, Enum.map(plans, &{plan_option_label(&1), &1.code}))
    |> assign(:current_plan, current_plan)
    |> assign(:pending_plan, pending_plan)
    |> assign(:plan_params, plan_params)
    |> assign(:plan_form, plan_form)
    |> assign(:timing_options, timing_options())
    |> assign(:upi_restricted?, upi_restricted?(subscription))
    |> assign(:invoice_error, invoice_error)
    |> stream(:invoices, invoices, reset: true)
  end

  defp load_invoices(nil, _socket), do: {[], false}

  defp load_invoices(subscription, socket) do
    if connected?(socket) do
      case Billing.list_invoices(subscription.provider_subscription_id, 10) do
        {:ok, invoices} -> {invoices, false}
        {:error, _reason} -> {[], true}
      end
    else
      {[], false}
    end
  end

  defp selected_plan_code(socket) do
    socket.assigns.plan_params
    |> Map.get("plan_code", socket.assigns.current_scope.tenant.plan)
  end

  defp plan_label(nil), do: "No plan found"
  defp plan_label(plan), do: plan.name

  defp plan_price_label(nil), do: "—"

  defp plan_price_label(plan) do
    amount = format_amount(plan.amount, plan.currency)
    "#{amount} / month"
  end

  defp plan_option_label(plan) do
    "#{plan.name} — #{format_amount(plan.amount, plan.currency)}/mo"
  end

  defp pending_plan(nil, _plans), do: nil

  defp pending_plan(subscription, plans) do
    code = subscription.pending_plan_code
    Enum.find(plans, &(&1.code == code))
  end

  defp upcoming_payment_link(nil), do: nil

  defp upcoming_payment_link(subscription) do
    subscription.short_url
  end

  defp status_label(nil), do: "no subscription"
  defp status_label(subscription), do: subscription.status

  defp status_color(nil), do: "neutral"
  defp status_color(%{status: "active"}), do: "success"
  defp status_color(%{status: "pending"}), do: "warning"
  defp status_color(%{status: "halted"}), do: "warning"
  defp status_color(%{status: "paused"}), do: "info"
  defp status_color(%{status: "cancelled"}), do: "neutral"
  defp status_color(%{status: "completed"}), do: "neutral"
  defp status_color(%{status: "expired"}), do: "neutral"
  defp status_color(_), do: "neutral"

  defp cancel_disabled?(nil), do: true

  defp cancel_disabled?(%{cancelled_at: %DateTime{}}), do: true

  defp cancel_disabled?(%{status: status}) when status in ["cancelled", "completed", "expired"],
    do: true

  defp cancel_disabled?(_subscription), do: false

  defp cancellation_notice(nil, _tenant), do: nil

  defp cancellation_notice(%{status: status} = subscription, tenant) do
    cond do
      status in ["cancelled", "completed", "expired"] ->
        {:neutral, "Subscription cancelled."}

      is_struct(subscription.cancelled_at, DateTime) ->
        {:danger, "Cancellation scheduled for #{format_date(subscription.cancelled_at, tenant)}."}

      true ->
        nil
    end
  end

  defp upi_restricted?(nil), do: false

  defp upi_restricted?(subscription) do
    subscription.payment_method
    |> to_string()
    |> String.downcase() == "upi"
  end

  defp pay_again_disabled?(nil, _upi_restricted?), do: true
  defp pay_again_disabled?(_subscription, false), do: false

  defp pay_again_disabled?(subscription, true) do
    case subscription.current_end_at do
      %DateTime{} = end_at -> DateTime.compare(end_at, DateTime.utc_now()) == :gt
      _ -> true
    end
  end

  defp format_date(nil, _tenant), do: "—"
  defp format_date(%DateTime{} = dt, tenant), do: Formatting.date(dt, tenant)

  defp format_date(%{start_at: start_at, end_at: end_at}, tenant) do
    "#{format_date(start_at, tenant)} – #{format_date(end_at, tenant)}"
  end

  defp format_unix(nil, _tenant), do: "—"

  defp format_unix(value, tenant) when is_integer(value) do
    case DateTime.from_unix(value) do
      {:ok, dt} -> Formatting.date(dt, tenant)
      _ -> "—"
    end
  end

  defp usage_value(counters, key) do
    counters |> Map.get(key, 0) |> to_string()
  end

  defp entitlement_value(entitlements, key) do
    case Map.get(entitlements, key) do
      nil -> "Unlimited"
      value -> to_string(value)
    end
  end

  defp format_amount(nil, _currency), do: "—"

  defp format_amount(amount, currency) when is_integer(amount) do
    value = amount / 100
    formatted = :erlang.float_to_binary(value, decimals: 2)

    case currency do
      "INR" -> "₹#{formatted}"
      "USD" -> "$#{formatted}"
      _ -> "#{formatted} #{currency || ""}"
    end
  end

  defp timing_options do
    [
      {"Now", "now"},
      {"At cycle end", "cycle_end"}
    ]
  end

  defp invoice_dom_id(invoice) do
    "invoice-#{Map.get(invoice, "id") || System.unique_integer([:positive])}"
  end

  defp handle_billing_error(socket, %Swati.Billing.Error{} = error) do
    socket
    |> put_flash(:error, error.user_message || "Billing action failed.")
    |> assign(:plan_notice, error.provider_message || error.user_message)
  end

  # Pay-again is only needed for UPI subscriptions because Razorpay blocks in-place updates.
  # "Failed" maps to a halted subscription after payment failures.
  defp show_pay_again?(nil, _upi_restricted?), do: false
  defp show_pay_again?(_subscription, false), do: false

  defp show_pay_again?(subscription, true) do
    subscription.status in ["halted", "expired"]
  end

  defp unauthorized(socket) do
    socket
    |> put_flash(:error, "You do not have access to manage billing.")
    |> redirect(to: ~p"/")
  end
end
