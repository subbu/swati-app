defmodule SwatiWeb.TrustConsoleLive.Rejections do
  use SwatiWeb, :live_view

  alias Swati.Calls
  alias SwatiWeb.CallsLive.Helpers, as: CallsHelpers

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_scope.tenant
    rejections = Calls.list_call_rejections(tenant.id)

    {:ok,
     socket
     |> assign(:rejections, rejections)
     |> assign(:active_tab, :rejections)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="trust-rejections" class="space-y-6">
        <header class="flex flex-wrap items-center justify-between gap-4 border-b border-base pb-4">
          <div>
            <h1 class="text-xl font-semibold text-foreground">Rejected Calls</h1>
            <p class="text-sm text-foreground-soft">Inbound calls rejected before streaming.</p>
          </div>
          <div class="flex items-center gap-2 text-sm text-foreground-soft">
            <span class="font-semibold text-foreground">{length(@rejections)}</span>
            <span>recent rejections</span>
          </div>
        </header>

        <nav class="flex flex-wrap items-center gap-2 text-sm">
          <.link patch={~p"/trust"} class={nav_class(@active_tab == :timeline)}>
            Timeline
          </.link>
          <.link patch={~p"/trust/policy"} class={nav_class(@active_tab == :policy)}>
            Policy
          </.link>
          <.link patch={~p"/trust/reliability"} class={nav_class(@active_tab == :reliability)}>
            Reliability
          </.link>
          <.link patch={~p"/trust/rejections"} class={nav_class(@active_tab == :rejections)}>
            Rejections
          </.link>
        </nav>

        <section class="rounded-base border border-base bg-base p-4">
          <div :if={@rejections == []} class="text-sm text-foreground-soft">
            No rejected calls yet.
          </div>
          <div :if={@rejections != []} class="overflow-x-auto">
            <.table id="trust-rejections-table">
              <.table_head class="text-foreground-soft">
                <:col>Time</:col>
                <:col>Endpoint</:col>
                <:col>Caller</:col>
                <:col>Reason</:col>
                <:col>Action</:col>
                <:col class="text-right">Retryable</:col>
              </.table_head>
              <.table_body>
                <.table_row :for={rejection <- @rejections}>
                  <:cell class="text-foreground-soft">
                    {format_ts(rejection.inserted_at, @current_scope.tenant)}
                  </:cell>
                  <:cell class="text-foreground">
                    <div class="font-medium">
                      {CallsHelpers.format_phone(rejection.to_address, @current_scope.tenant)}
                    </div>
                    <div class="text-xs text-foreground-soft">
                      {rejection.provider_call_id || "—"}
                    </div>
                  </:cell>
                  <:cell class="text-foreground">
                    {CallsHelpers.format_phone(rejection.from_address, @current_scope.tenant)}
                  </:cell>
                  <:cell>
                    <.badge size="xs" variant="soft" color="warning">
                      {format_reason(rejection.reason_code)}
                    </.badge>
                    <div class="text-xs text-foreground-soft mt-1">
                      {rejection.reason_message || "—"}
                    </div>
                  </:cell>
                  <:cell class="text-foreground-soft">
                    {rejection.action || "—"}
                  </:cell>
                  <:cell class="text-right text-foreground-soft">
                    {if rejection.retryable, do: "yes", else: "no"}
                  </:cell>
                </.table_row>
              </.table_body>
            </.table>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp format_ts(nil, _tenant), do: "—"

  defp format_ts(%NaiveDateTime{} = ts, tenant) do
    ts
    |> DateTime.from_naive!("Etc/UTC")
    |> CallsHelpers.format_datetime(tenant)
  end

  defp format_ts(%DateTime{} = ts, tenant), do: CallsHelpers.format_datetime(ts, tenant)

  defp format_reason(nil), do: "unknown"

  defp format_reason(reason) do
    reason
    |> to_string()
    |> String.replace("_", " ")
  end

  defp nav_class(true), do: "px-3 py-1.5 rounded-base bg-accent text-foreground font-medium"
  defp nav_class(false), do: "px-3 py-1.5 rounded-base text-foreground-soft hover:bg-accent"
end
