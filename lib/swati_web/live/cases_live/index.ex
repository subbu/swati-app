defmodule SwatiWeb.CasesLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Cases
  alias Swati.Repo
  alias SwatiWeb.CasesLive.Helpers, as: CasesHelpers

  @impl true
  def mount(_params, _session, socket) do
    filters = %{"status" => ""}

    {:ok,
     socket
     |> assign(:filters, filters)
     |> assign(:status_options, status_options())
     |> assign(:filter_form, to_form(filters, as: :filters))
     |> load_cases()}
  end

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    filters = normalize_filters(filters)

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:filter_form, to_form(filters, as: :filters))
     |> load_cases(reset: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <header class="flex flex-wrap items-center gap-4 border-b border-base pb-4">
          <div class="flex items-center gap-3">
            <div class="size-9 flex items-center justify-center rounded-lg bg-radial from-amber-400 to-amber-600 text-white shadow">
              <.icon name="hero-briefcase" class="size-4" />
            </div>
            <div>
              <h1 class="text-xl font-semibold text-foreground">Cases</h1>
              <p class="text-sm text-foreground-soft">Case-centric timeline across sessions.</p>
            </div>
          </div>
          <div class="ml-auto flex items-center gap-2 text-sm text-foreground-soft">
            <span class="font-semibold text-foreground">{@case_count}</span>
            <span>cases</span>
          </div>
        </header>

        <section class="rounded-base bg-base overflow-hidden">
          <div class="flex flex-wrap items-center gap-3 px-4 py-3 border-b border-base">
            <.form for={@filter_form} id="cases-filter" phx-change="filter">
              <.select
                field={@filter_form[:status]}
                label="Status"
                options={@status_options}
                class="min-w-[12rem]"
                native
              />
            </.form>
          </div>

          <div class="overflow-x-auto">
            <.table id="cases-table">
              <.table_head class="text-foreground-soft [&_th:first-child]:pl-4!">
                <:col class="py-2">Case</:col>
                <:col class="py-2">Status</:col>
                <:col class="py-2">Priority</:col>
                <:col class="py-2">Customer</:col>
                <:col class="py-2 w-full">Updated</:col>
              </.table_head>
              <.table_body id="cases" phx-update="stream" class="text-foreground-soft">
                <.table_row
                  :for={{id, case_record} <- @streams.cases}
                  id={id}
                  class="[&_td:first-child]:pl-4! [&_td:last-child]:pr-4! hover:bg-accent/50 transition-colors group"
                >
                  <:cell class="py-2 align-middle">
                    <.link navigate={~p"/cases/#{case_record.id}"} class="text-foreground font-medium">
                      {case_record.title || "Untitled case"}
                    </.link>
                    <div class="text-xs text-foreground-softest">
                      {case_record.category || "General"}
                    </div>
                  </:cell>
                  <:cell class="py-2 align-middle">
                    <% badge = CasesHelpers.status_badge(case_record.status) %>
                    <.badge size="sm" variant="soft" color={badge.color}>{badge.label}</.badge>
                  </:cell>
                  <:cell class="py-2 align-middle">
                    <% badge = CasesHelpers.priority_badge(case_record.priority) %>
                    <.badge size="sm" variant="soft" color={badge.color}>{badge.label}</.badge>
                  </:cell>
                  <:cell class="py-2 align-middle">
                    <span class="text-foreground font-medium">
                      {CasesHelpers.customer_name(case_record)}
                    </span>
                  </:cell>
                  <:cell class="py-2 align-middle">
                    <div class="flex flex-col">
                      <span class="text-foreground font-medium">
                        {CasesHelpers.format_relative(case_record.updated_at, @current_scope.tenant)}
                      </span>
                      <span class="text-xs text-foreground-softest">
                        {CasesHelpers.format_datetime(case_record.updated_at, @current_scope.tenant)}
                      </span>
                    </div>
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

  defp load_cases(socket, opts \\ []) do
    tenant_id = socket.assigns.current_scope.tenant.id

    cases =
      Cases.list_cases(tenant_id, socket.assigns.filters)
      |> Repo.preload([:customer])

    socket = assign(socket, :case_count, length(cases))

    if Keyword.get(opts, :reset, false) do
      stream(socket, :cases, cases, reset: true)
    else
      stream(socket, :cases, cases)
    end
  end

  defp status_options do
    [
      {"All statuses", ""},
      {"New", "new"},
      {"Triage", "triage"},
      {"In progress", "in_progress"},
      {"Waiting", "waiting_on_customer"},
      {"Resolved", "resolved"},
      {"Closed", "closed"}
    ]
  end

  defp normalize_filters(filters) when is_map(filters) do
    %{"status" => Map.get(filters, "status") || ""}
  end
end
