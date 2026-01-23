defmodule SwatiWeb.CustomersLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Customers
  alias Swati.Customers.Customer
  alias Swati.Repo
  alias SwatiWeb.CustomersLive.Helpers, as: CustomersHelpers

  @impl true
  def mount(_params, _session, socket) do
    filters = %{"status" => "", "query" => ""}
    sort = sort_assign(%{})
    page_size = 20

    socket =
      socket
      |> assign(:filters, filters)
      |> assign(:filters_active, filters_active?(filters))
      |> assign(:filter_form, to_form(filters, as: :filters))
      |> assign(:status_options, CustomersHelpers.status_options())
      |> assign(:sort, sort)
      |> assign(:page, 1)
      |> assign(:page_size, page_size)
      |> assign(
        :pagination,
        %{page: 1, page_size: page_size, total_pages: 1, total_count: 0}
      )
      |> assign(:edit_modal_open, false)
      |> assign(:edit_customer, nil)
      |> assign(:edit_form, to_form(%{}, as: :customer))

    {:ok, load_customers(socket)}
  end

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    merged_filters = Map.merge(socket.assigns.filters, filters)

    {:noreply,
     socket
     |> assign(:filters, merged_filters)
     |> assign(:filters_active, filters_active?(merged_filters))
     |> assign(:filter_form, to_form(merged_filters, as: :filters))
     |> assign(:page, 1)
     |> load_customers(reset: true)}
  end

  @impl true
  def handle_event("reset_filters", _params, socket) do
    filters = %{"status" => "", "query" => ""}

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:filters_active, false)
     |> assign(:filter_form, to_form(filters, as: :filters))
     |> assign(:page, 1)
     |> load_customers(reset: true)}
  end

  @impl true
  def handle_event("sort", %{"column" => column}, socket) do
    sort = CustomersHelpers.next_sort(socket.assigns.sort, column)

    {:noreply,
     socket
     |> assign(:sort, sort)
     |> assign(:page, 1)
     |> load_customers(reset: true)}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = parse_page(page, socket.assigns.pagination)

    {:noreply,
     socket
     |> assign(:page, page)
     |> load_customers(reset: true)}
  end

  @impl true
  def handle_event("open-edit-modal", %{"id" => id}, socket) do
    tenant_id = socket.assigns.current_scope.tenant.id
    customer = Customers.get_customer!(tenant_id, id)
    form = customer |> Customer.changeset(%{}) |> to_form()

    {:noreply,
     socket
     |> assign(:edit_customer, customer)
     |> assign(:edit_form, form)
     |> assign(:edit_modal_open, true)}
  end

  @impl true
  def handle_event("close-edit-modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:edit_modal_open, false)
     |> assign(:edit_customer, nil)
     |> assign(:edit_form, to_form(%{}, as: :customer))}
  end

  @impl true
  def handle_event("validate-edit", %{"customer" => params}, socket) do
    case socket.assigns.edit_customer do
      %Customer{} = customer ->
        changeset =
          customer
          |> Customer.changeset(params)
          |> Map.put(:action, :validate)

        {:noreply, assign(socket, :edit_form, to_form(changeset))}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("save-edit", %{"customer" => params}, socket) do
    case socket.assigns.edit_customer do
      %Customer{} = customer ->
        attrs = Map.take(params, ["name"])

        case Customers.update_customer(customer, attrs) do
          {:ok, updated_customer} ->
            updated_customer = Repo.preload(updated_customer, identities: :channel)

            {:noreply,
             socket
             |> stream_insert(:customers, updated_customer)
             |> assign(:edit_modal_open, false)
             |> assign(:edit_customer, nil)
             |> assign(:edit_form, to_form(%{}, as: :customer))}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :edit_form, to_form(changeset))}
        end

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <header class="flex flex-wrap items-center gap-4 border-b border-base pb-4">
          <div class="flex items-center gap-3">
            <div class="size-9 flex items-center justify-center rounded-lg bg-radial from-sky-400 to-sky-600 text-white shadow">
              <.icon name="hero-user" class="size-4" />
            </div>
            <div>
              <h1 class="text-xl font-semibold text-foreground">Customers</h1>
              <p class="text-sm text-foreground-soft">Browse customer profiles and identities.</p>
            </div>
          </div>
          <div class="ml-auto flex items-center gap-2 text-sm text-foreground-soft">
            <span class="font-semibold text-foreground">{@customer_count}</span>
            <span>customers</span>
          </div>
        </header>

        <section class="rounded-base bg-base overflow-hidden">
          <div class="flex flex-wrap items-center gap-2 px-4 py-3 border-b border-base">
            <.form
              for={@filter_form}
              id="customers-filter"
              phx-change="filter"
              class="flex items-center gap-2"
            >
              <.input
                field={@filter_form[:query]}
                type="text"
                placeholder="Search customers"
                phx-debounce="300"
                class="min-w-[16rem] lg:min-w-[20rem]"
              >
                <:inner_prefix>
                  <.icon name="hero-magnifying-glass" class="icon" />
                </:inner_prefix>
              </.input>
            </.form>

            <.dropdown placement="bottom-start">
              <:toggle>
                <.button variant="dashed">
                  <.icon name="hero-adjustments-horizontal" class="icon" />
                  <span class="hidden lg:inline ml-1">
                    {CustomersHelpers.status_filter_label(@filters)}
                  </span>
                </.button>
              </:toggle>
              <.dropdown_button phx-click={JS.push("filter", value: %{filters: %{"status" => ""}})}>
                All statuses
              </.dropdown_button>
              <.dropdown_button
                :for={{label, value} <- @status_options |> Enum.reject(&(elem(&1, 1) == ""))}
                phx-click={JS.push("filter", value: %{filters: %{"status" => value}})}
              >
                {label}
              </.dropdown_button>
            </.dropdown>

            <%= if @filters_active do %>
              <.button
                size="xs"
                variant="ghost"
                type="button"
                phx-click="reset_filters"
                aria-label="Reset filters"
              >
                <.icon name="hero-x-mark" class="icon" />
                <span class="hidden lg:inline ml-1">Reset filters</span>
              </.button>
            <% end %>
          </div>

          <div class="overflow-x-auto">
            <.table id="customers-table">
              <.table_head class="text-foreground-soft [&_th:first-child]:pl-4!">
                <:col
                  class="py-2 w-56"
                  phx-click="sort"
                  phx-value-column="name"
                  data-column="customer"
                >
                  <button type="button" class={CustomersHelpers.sort_button_class("name", @sort)}>
                    Customer <CustomersHelpers.sort_icon column="name" sort={@sort} />
                  </button>
                </:col>
                <:col
                  class="py-2 w-28"
                  phx-click="sort"
                  phx-value-column="status"
                  data-column="status"
                >
                  <button type="button" class={CustomersHelpers.sort_button_class("status", @sort)}>
                    Status <CustomersHelpers.sort_icon column="status" sort={@sort} />
                  </button>
                </:col>
                <:col class="py-2 w-full" data-column="identities">
                  Identities
                </:col>
                <:col
                  class="py-2 w-44"
                  phx-click="sort"
                  phx-value-column="updated_at"
                  data-column="updated_at"
                >
                  <button
                    type="button"
                    class={CustomersHelpers.sort_button_class("updated_at", @sort)}
                  >
                    Updated <CustomersHelpers.sort_icon column="updated_at" sort={@sort} />
                  </button>
                </:col>
                <:col class="py-2 text-right"></:col>
              </.table_head>
              <.table_body id="customers" phx-update="stream" class="text-foreground-soft">
                <.table_row
                  :for={{id, customer} <- @streams.customers}
                  id={id}
                  class="[&_td:first-child]:pl-4! [&_td:last-child]:pr-4! hover:bg-accent/50 transition-colors"
                >
                  <:cell class="py-2 align-top">
                    <span class="text-foreground font-medium">
                      {CustomersHelpers.customer_name(customer)}
                    </span>
                    <div class="text-xs text-foreground-softest">
                      {CustomersHelpers.customer_contact(customer)}
                    </div>
                  </:cell>
                  <:cell class="py-2 align-top">
                    <% badge = CustomersHelpers.status_badge(customer.status) %>
                    <.badge size="sm" variant="soft" color={badge.color}>{badge.label}</.badge>
                  </:cell>
                  <:cell class="py-2 align-top">
                    <%= if customer.identities == [] do %>
                      <span class="text-xs text-foreground-softest">No identities</span>
                    <% else %>
                      <div class="flex flex-col gap-2">
                        <div
                          :for={group <- CustomersHelpers.identity_groups(customer.identities)}
                          class="flex items-start gap-3 text-sm"
                        >
                          <div class="mt-0.5 flex size-9 shrink-0 items-center justify-center rounded-full bg-accent/50">
                            <.icon
                              name={group.icon}
                              class="size-4 text-foreground-softer"
                            />
                          </div>
                          <div class="min-w-0 leading-tight">
                            <div class="text-foreground font-semibold truncate">
                              {group.address}
                            </div>
                            <div class="text-xs text-foreground-softest">
                              {CustomersHelpers.identity_channels_label(group.channels)}
                            </div>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </:cell>
                  <:cell class="py-2 align-top">
                    <div class="flex flex-col">
                      <span class="text-foreground font-medium">
                        {CustomersHelpers.format_relative(customer.updated_at, @current_scope.tenant)}
                      </span>
                      <span class="text-xs text-foreground-softest">
                        {CustomersHelpers.format_datetime(customer.updated_at, @current_scope.tenant)}
                      </span>
                    </div>
                  </:cell>
                  <:cell class="py-2 align-top text-right">
                    <.dropdown placement="bottom-end">
                      <:toggle>
                        <.button size="sm" variant="ghost">
                          <.icon name="hero-ellipsis-vertical" class="size-4" />
                        </.button>
                      </:toggle>
                      <.dropdown_link navigate={~p"/sessions?#{%{customer_id: customer.id}}"}>
                        <.icon name="hero-chat-bubble-left-right" class="icon" /> View conversations
                      </.dropdown_link>
                      <.dropdown_button phx-click="open-edit-modal" phx-value-id={customer.id}>
                        <.icon name="hero-pencil-square" class="icon" /> Edit name
                      </.dropdown_button>
                    </.dropdown>
                  </:cell>
                </.table_row>
              </.table_body>
            </.table>
          </div>

          <div
            id="customers-pagination"
            class="flex flex-wrap items-center justify-between gap-3 border-t border-base px-4 py-3 text-sm text-foreground-soft"
          >
            <% {range_start, range_end} = pagination_range(@pagination) %>
            <div class="flex items-center gap-2">
              <span class="font-medium text-foreground">
                {range_start}-{range_end}
              </span>
              <span>of</span>
              <span class="font-medium text-foreground">{@pagination.total_count}</span>
              <span>customers</span>
            </div>
            <div class="flex items-center gap-2">
              <.button
                id="customers-first-page"
                size="sm"
                variant="ghost"
                type="button"
                phx-click="paginate"
                phx-value-page="1"
                disabled={@pagination.page == 1}
              >
                <.icon name="hero-chevron-double-left" class="size-4" />
              </.button>
              <.button
                id="customers-prev-page"
                size="sm"
                variant="ghost"
                type="button"
                phx-click="paginate"
                phx-value-page={@pagination.page - 1}
                disabled={@pagination.page <= 1}
              >
                <.icon name="hero-chevron-left" class="size-4" />
                <span class="sr-only">Previous page</span>
              </.button>
              <span class="text-xs text-foreground-soft">
                Page <span class="font-semibold text-foreground">{@pagination.page}</span>
                of <span class="font-semibold text-foreground">{@pagination.total_pages}</span>
              </span>
              <.button
                id="customers-next-page"
                size="sm"
                variant="ghost"
                type="button"
                phx-click="paginate"
                phx-value-page={@pagination.page + 1}
                disabled={@pagination.page >= @pagination.total_pages}
              >
                <span class="sr-only">Next page</span>
                <.icon name="hero-chevron-right" class="size-4" />
              </.button>
              <.button
                id="customers-last-page"
                size="sm"
                variant="ghost"
                type="button"
                phx-click="paginate"
                phx-value-page={@pagination.total_pages}
                disabled={@pagination.page >= @pagination.total_pages}
              >
                <.icon name="hero-chevron-double-right" class="size-4" />
              </.button>
            </div>
          </div>
        </section>
      </div>

      <.modal
        id="customer-edit-modal"
        class="w-full max-w-lg p-0"
        open={@edit_modal_open}
        on_close={JS.push("close-edit-modal")}
      >
        <div class="flex flex-col">
          <div class="flex items-start justify-between gap-4 border-b border-base p-6">
            <div>
              <h3 class="text-lg font-semibold text-foreground">Edit customer name</h3>
              <p class="text-sm text-foreground-soft">
                Update the display name for this customer.
              </p>
            </div>
          </div>

          <div class="space-y-6 overflow-y-auto p-6">
            <.form
              for={@edit_form}
              id="customer-edit-form"
              phx-change="validate-edit"
              phx-submit="save-edit"
              class="space-y-4"
            >
              <.input field={@edit_form[:name]} type="text" label="Customer name" />

              <div class="flex items-center justify-end gap-2">
                <.button type="button" size="sm" variant="ghost" phx-click="close-edit-modal">
                  Cancel
                </.button>
                <.button type="submit" size="sm">
                  Save
                </.button>
              </div>
            </.form>
          </div>
        </div>
      </.modal>
    </Layouts.app>
    """
  end

  defp load_customers(socket, opts \\ []) do
    tenant_id = socket.assigns.current_scope.tenant.id

    {customers, pagination} =
      case Customers.list_customers_paginated(
             tenant_id,
             socket.assigns.filters,
             flop_params(socket)
           ) do
        {:ok, {customers, pagination}} -> {customers, pagination}
        {:error, pagination} -> {[], pagination}
      end

    pagination =
      ensure_pagination_defaults(pagination, socket.assigns.page, socket.assigns.page_size)

    customers = Repo.preload(customers, identities: :channel)

    socket =
      socket
      |> assign(:customer_count, pagination.total_count)
      |> assign(:pagination, pagination)

    if Keyword.get(opts, :reset, false) do
      stream(socket, :customers, customers, reset: true)
    else
      stream(socket, :customers, customers)
    end
  end

  defp sort_assign(sort) do
    column = Map.get(sort, "column") || Map.get(sort, :column) || "updated_at"
    direction = Map.get(sort, "direction") || Map.get(sort, :direction) || "desc"

    %{column: to_string(column), direction: to_string(direction)}
  end

  defp flop_params(socket) do
    %{
      page: socket.assigns.page,
      page_size: socket.assigns.page_size,
      order_by: [sort_field(socket.assigns.sort.column)],
      order_directions: [sort_direction(socket.assigns.sort.direction)]
    }
  end

  defp sort_field("name"), do: :name
  defp sort_field("status"), do: :status
  defp sort_field("inserted_at"), do: :inserted_at
  defp sort_field("updated_at"), do: :updated_at
  defp sort_field(_), do: :updated_at

  defp sort_direction("asc"), do: :asc
  defp sort_direction(_), do: :desc

  defp filters_active?(filters) do
    query = filters |> Map.get("query", "") |> to_string() |> String.trim()

    Map.get(filters, "status") not in [nil, ""] or query != ""
  end

  defp pagination_range(%{total_count: total_count}) when total_count in [nil, 0] do
    {0, 0}
  end

  defp pagination_range(%{page: page, page_size: page_size, total_count: total_count}) do
    start_index = max((page - 1) * page_size + 1, 1)
    end_index = min(page * page_size, total_count)

    {start_index, end_index}
  end

  defp parse_page(page, pagination) do
    parsed_page =
      case Integer.parse(to_string(page)) do
        {value, ""} -> value
        _ -> pagination.page || 1
      end

    parsed_page
    |> max(1)
    |> min(pagination.total_pages || 1)
  end

  defp ensure_pagination_defaults(pagination, page, page_size) do
    %{
      page: Map.get(pagination, :page) || page,
      page_size: Map.get(pagination, :page_size) || page_size,
      total_pages: Map.get(pagination, :total_pages) || 1,
      total_count: Map.get(pagination, :total_count) || 0
    }
  end
end
