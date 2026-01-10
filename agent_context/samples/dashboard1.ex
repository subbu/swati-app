# --- INFO ---
# This LiveView serves as a demonstration for the Fluxon UI components.
# For simplicity, all data fetching, state management, and business logic
# are handled directly within this module using hardcoded data (@invoices).
# In a real-world application, you would typically extract data handling
# into dedicated context modules and potentially use a database via Ecto.
# The primary goal here is to illustrate the integration and usage of
# Fluxon components in a LiveView setting.
# -----------

defmodule Invoice do
  use Ecto.Schema
  import Ecto.Changeset

  # embedded_schema since it's not persisting to DB
  embedded_schema do
    field :number, :string
    field :customer, :string
    field :amount, :decimal
    field :due_date, :string
    field :status, :string
  end

  def changeset(invoice, attrs) do
    invoice
    |> cast(attrs, [:customer, :amount])
    |> validate_required([:customer])
    |> validate_required([:amount])
    |> validate_length(:customer, min: 2, max: 100)
    |> validate_number(:amount, greater_than: 1000)
  end
end

defmodule MyAppWeb.InvoiceManagementLive do
  use MyAppWeb, :live_view

  @invoices [
    %Invoice{
      number: "INV-2024-001",
      customer: "Acme Corp",
      due_date: "Mar 15, 2024",
      amount: 2500.00,
      status: :paid
    },
    %Invoice{
      number: "INV-2024-002",
      customer: "TechStart Inc",
      due_date: "Mar 18, 2024",
      amount: 1750.00,
      status: :paid
    },
    %Invoice{
      number: "INV-2024-003",
      customer: "Global Systems",
      due_date: "Mar 20, 2024",
      amount: 3200.00,
      status: :overdue
    },
    %Invoice{
      number: "INV-2024-004",
      customer: "Data Solutions",
      due_date: "Mar 22, 2024",
      amount: 950.00,
      status: :paid
    },
    %Invoice{
      number: "INV-2024-005",
      customer: "Cloud Nine Ltd",
      due_date: "Mar 25, 2024",
      amount: 4100.00,
      status: :pending
    }
  ]

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Invoice Management",
       invoices: @invoices,
       sort: nil,
       invoice_details: nil,
       invoice_form: to_form(Invoice.changeset(%Invoice{}, %{})),
       visible_columns: ~w(due_date invoice_number status),
       columns_form:
         to_form(%{
           "invoice_number" => true,
           "due_date" => true,
           "amount" => true,
           "status" => true
         })
     )}
  end

  def render(assigns) do
    ~H"""
    <.sheet id="mobile-sidebar-nav" placement="left" class="w-full max-w-xs">
      <div class="flex mb-6 shrink-0 items-center">
        <img src="https://fluxonui.com/images/logos/1.svg" alt="Fluxon" class="h-7 w-auto" />
      </div>

      <.navlist heading="Main">
        <.navlink navigate="/dashboard">
          <.icon name="hero-squares-2x2" class="size-5 text-foreground-softer group-hover:text-foreground" /> Overview
        </.navlink>
        <.navlink navigate="/invoices">
          <.icon name="hero-document-text" class="size-5 text-foreground-softer group-hover:text-foreground" />
          <span class="flex-1">Invoices</span>
          <.icon name="hero-star-solid" class="size-4 text-orange-400 ml-auto" />
        </.navlink>
        <.navlink navigate="/customers">
          <.icon name="hero-users" class="size-5 text-foreground-softer group-hover:text-foreground" />
          <span class="flex-1">Customers</span>
          <.icon name="hero-star-solid" class="size-4 text-orange-400 ml-auto" />
        </.navlink>
        <.navlink navigate="/payments">
          <.icon name="hero-credit-card" class="size-5 text-foreground-softer group-hover:text-foreground" /> Payments
        </.navlink>
        <.navlink navigate="/reports">
          <.icon name="hero-chart-bar" class="size-5 text-foreground-softer group-hover:text-foreground" />
          <span class="flex-1">Reports</span>
          <.badge color="info" class="ml-auto">New</.badge>
        </.navlink>
        <.navlink navigate="/tasks">
          <.icon name="hero-adjustments-horizontal" class="size-5 text-foreground-softer group-hover:text-foreground" />
          <span class="flex-1">Tasks</span>
          <.tooltip value="Add to favorites">
            <.icon name="hero-star" class="size-4 ml-auto text-foreground-softer" />
          </.tooltip>
        </.navlink>
        <.navlink navigate="/archive">
          <.icon name="hero-archive-box" class="size-5 text-foreground-softer group-hover:text-foreground" />
          <span class="flex-1">Archive</span>
          <.tooltip value="Add to favorites">
            <.icon name="hero-star" class="size-4 ml-auto text-foreground-softer" />
          </.tooltip>
        </.navlink>
      </.navlist>

      <.navlist heading="Projects">
        <.navlink phx-click={JS.toggle_attribute({"data-expanded", ""})} class="group" data-expanded>
          <span class="flex size-2 rounded-full bg-red-500 group-data-[active]:bg-red-600"></span>
          <span class="flex-1">Fluxon Project</span>
          <.icon
            name="hero-chevron-right"
            class="size-4 ml-auto text-foreground-softer group-data-[active]:text-inherit in-data-expanded:rotate-90 transition-transform duration-200"
          />
        </.navlink>
        <div class="grid grid-rows-[0fr] [[data-expanded]~&]:grid-rows-[1fr] transition-all duration-200">
          <div class="overflow-hidden ml-4">
            <.navlink navigate="/projects/fluxon/api" class="group">
              <span class="flex size-2 rounded-full bg-zinc-400 group-data-[active]:bg-zinc-500"></span> API Integration
            </.navlink>
            <.navlink navigate="/projects/fluxon/ui" class="group">
              <span class="flex size-2 rounded-full bg-zinc-400 group-data-[active]:bg-zinc-500"></span> UI Refresh
            </.navlink>
          </div>
        </div>
        <.navlink navigate="/projects/website" class="group">
          <span class="flex size-2 rounded-full bg-blue-500 group-data-[active]:bg-blue-600"></span> Website Redesign
        </.navlink>
        <.navlink navigate="/projects/mobile" class="group">
          <span class="flex size-2 rounded-full bg-green-500 group-data-[active]:bg-green-600"></span> Mobile App
        </.navlink>
      </.navlist>

      <.navlist class="mt-auto!">
        <.navlink navigate="/settings">
          <.icon name="hero-cog-6-tooth" class="size-5 text-foreground-softer group-hover:text-foreground" /> Settings
        </.navlink>
        <.navlink navigate="/help">
          <.icon name="hero-question-mark-circle" class="size-5 text-foreground-softer group-hover:text-foreground" />
          Help & Support
        </.navlink>
      </.navlist>
    </.sheet>

    <div class="relative isolate flex min-h-svh w-full bg-base max-lg:flex-col">
      <div class="z-50 fixed inset-y-0 left-0 w-72 max-lg:hidden border-r border-base">
        <div class="flex h-full flex-col">
          <div class="flex flex-1 flex-col overflow-y-auto p-6">
            <div class="flex items-center justify-between mb-8">
              <div class="flex shrink-0 items-center gap-2">
                <img src="https://fluxonui.com/images/logos/1.svg" alt="Fluxon" class="h-6 w-auto" />
                <span class="text-xl font-bold text-foreground">AcmeCo</span>
              </div>
              <.dropdown class="w-56">
                <:toggle class="w-full">
                  <button class="cursor-pointer rounded-full size-6 overflow-hidden">
                    <img src="https://i.pravatar.cc/150?u=Mike+Doe" alt="John Doe" class="inline" />
                  </button>
                </:toggle>

                <.dropdown_link navigate="/profile">
                  <.icon name="hero-user-circle" class="icon" /> Your profile
                </.dropdown_link>
                <.dropdown_link navigate="/appearance">
                  <.icon name="hero-sun" class="icon" /> Appearance
                </.dropdown_link>
                <.dropdown_link navigate="/settings">
                  <.icon name="hero-cog-6-tooth" class="icon text-foreground-softer" /> Settings
                </.dropdown_link>
                <.dropdown_link navigate="/notifications">
                  <.icon name="hero-bell" class="icon text-foreground-softer" /> Notifications
                </.dropdown_link>

                <.dropdown_separator />

                <.dropdown_link navigate="/upgrade">
                  <.icon name="hero-star-solid" class="icon text-orange-600!" /> Upgrade
                  <.badge color="warning" class="ml-auto font-medium">20% off</.badge>
                </.dropdown_link>

                <.dropdown_link navigate="/referrals">
                  <.icon name="hero-gift" class="icon text-foreground-softer" /> Referrals
                </.dropdown_link>

                <.dropdown_link navigate="/download">
                  <.icon name="hero-arrow-down-circle" class="icon text-foreground-softer" /> Download app
                </.dropdown_link>

                <.dropdown_link navigate="/whats-new">
                  <.icon name="hero-sparkles" class="icon text-foreground-softer" /> What's new?
                </.dropdown_link>

                <.dropdown_link navigate="/help">
                  <.icon name="hero-question-mark-circle" class="icon text-foreground-softer" /> Get help?
                </.dropdown_link>

                <.dropdown_separator />

                <.dropdown_link
                  navigate="/signout"
                  class="text-red-600 data-highlighted:text-red-700 data-highlighted:bg-red-50"
                >
                  <.icon name="hero-arrow-right-on-rectangle" class="icon text-red-500" /> Sign out
                </.dropdown_link>
              </.dropdown>
            </div>

            <.navlist heading="Main">
              <.navlink navigate="/dashboard">
                <.icon name="hero-squares-2x2" class="size-5" /> Overview
              </.navlink>
              <.navlink navigate="/invoices" active>
                <.icon name="hero-document-text" class="size-5" />
                <span class="flex-1">Invoices</span>
                <.icon name="hero-star-solid" class="size-4 text-orange-400 ml-auto" />
              </.navlink>
              <.navlink navigate="/customers">
                <.icon name="hero-users" class="size-5" />
                <span class="flex-1">Customers</span>
                <.icon name="hero-star-solid" class="size-4 text-orange-400 ml-auto" />
              </.navlink>
              <.navlink navigate="/payments">
                <.icon name="hero-credit-card" class="size-5" /> Payments
              </.navlink>
              <.navlink navigate="/reports">
                <.icon name="hero-chart-bar" class="size-5" />
                <span class="flex-1">Reports</span>
                <.badge color="info" class="ml-auto">New</.badge>
              </.navlink>
              <.navlink navigate="/tasks">
                <.icon name="hero-adjustments-horizontal" class="size-5" />
                <span class="flex-1">Tasks</span>
                <.tooltip value="Add to favorites">
                  <.icon name="hero-star" class="size-4 ml-auto text-foreground-softer" />
                </.tooltip>
              </.navlink>
              <.navlink navigate="/archive">
                <.icon name="hero-archive-box" class="size-5" />
                <span class="flex-1">Archive</span>
                <.tooltip value="Add to favorites">
                  <.icon name="hero-star" class="size-4 ml-auto text-foreground-softer" />
                </.tooltip>
              </.navlink>
            </.navlist>

            <.navlist heading="Projects">
              <.navlink phx-click={JS.toggle_attribute({"data-expanded", ""})} class="group" data-expanded>
                <span class="flex size-2 rounded-full bg-red-500 group-data-[active]:bg-red-600"></span>
                <span class="flex-1">Fluxon Project</span>
                <.icon
                  name="hero-chevron-right"
                  class="size-4 ml-auto text-foreground-softer group-data-[active]:text-inherit in-data-expanded:rotate-90 transition-transform duration-200"
                />
              </.navlink>
              <div class="grid grid-rows-[0fr] [[data-expanded]~&]:grid-rows-[1fr] transition-all duration-200">
                <div class="overflow-hidden ml-2 px-2">
                  <.navlink navigate="/projects/fluxon/api" class="group">
                    <span class="flex size-2 rounded-full bg-zinc-400 group-data-[active]:bg-zinc-500"></span>
                    API Integration
                  </.navlink>
                  <.navlink navigate="/projects/fluxon/ui" class="group">
                    <span class="flex size-2 rounded-full bg-zinc-400 group-data-[active]:bg-zinc-500"></span> UI Refresh
                  </.navlink>
                </div>
              </div>
              <.navlink navigate="/projects/website" class="group">
                <span class="flex size-2 rounded-full bg-blue-500 group-data-[active]:bg-blue-600"></span> Website Redesign
              </.navlink>
              <.navlink navigate="/projects/mobile" class="group">
                <span class="flex size-2 rounded-full bg-green-500 group-data-[active]:bg-green-600"></span> Mobile App
              </.navlink>
            </.navlist>

            <.navlist class="mt-auto!">
              <.navlink navigate="/settings">
                <.icon name="hero-cog-6-tooth" class="size-5 text-foreground-softer group-hover:text-foreground" /> Settings
              </.navlink>
              <.navlink navigate="/help">
                <.icon name="hero-question-mark-circle" class="size-5 text-foreground-softer group-hover:text-foreground" />
                Help & Support
              </.navlink>
            </.navlist>
          </div>
        </div>
      </div>

      <main class="flex flex-1 flex-col lg:min-w-0 lg:pl-72">
        <header class="bg-base sticky z-10 top-0 flex h-14 shrink-0 items-center gap-x-3 border-b border-base px-4 sm:px-6">
          <button
            phx-click={Fluxon.open_dialog("mobile-sidebar-nav")}
            class="relative cursor-pointer flex min-w-0 items-center -m-2 p-2 lg:hidden"
          >
            <.icon name="hero-bars-3" class="size-6" />
          </button>

          <.separator vertical class="my-5 lg:hidden" />

          <h1 class="text-lg font-semibold text-foreground flex items-center gap-x-2">
            <div class="size-6 flex items-center justify-center rounded-md text-white bg-radial from-blue-500 to-blue-600 shadow">
              <.icon name="hero-document-text" class="size-4" />
            </div>
            Invoices
          </h1>

          <span class="text-foreground hidden sm:block">/</span>

          <span class="text-foreground font-medium text-sm hidden sm:block">10 invoices</span>

          <div class="ml-auto flex items-center gap-x-4 lg:gap-x-6">
            <.button variant="solid" phx-click={Fluxon.open_dialog("new-invoice-modal")} class="-mx-2 px-2">
              <.icon name="hero-plus" class="size-4" /> Create Invoice
            </.button>
          </div>
        </header>

        <div class="grow lg:rounded-base">
          <div class="flex items-center px-4 py-2 gap-x-2 border-b border-base">
            <.input type="text" name="search" placeholder="Search invoices">
              <:inner_prefix>
                <.icon name="hero-magnifying-glass" class="icon" />
              </:inner_prefix>
            </.input>

            <.dropdown
              placement="bottom-start"
              label="Sort order"
              class="w-48 [&:has(.phx-click-loading)_[data-loading]]:flex"
            >
              <:toggle>
                <.button variant="dashed">
                  <.icon name="hero-bars-arrow-down" class="icon" />
                  <span class="hidden lg:inline ml-1">Sorting</span>
                </.button>
              </:toggle>
              <div class="absolute inset-px bg-base/70 items-center justify-center hidden" data-loading>
                <.loading class="text-foreground-softer" />
              </div>
              <.dropdown_link phx-click={JS.push("sort_invoices", value: %{sort: "customer"})}>
                Customer
              </.dropdown_link>
              <.dropdown_link phx-click={JS.push("sort_invoices", value: %{sort: "amount"})}>Amount</.dropdown_link>
              <.dropdown_link phx-click={JS.push("sort_invoices", value: %{sort: "status"})}>Status</.dropdown_link>
            </.dropdown>
            <.popover
              id="columns-popover"
              placement="bottom-start"
              class="min-w-48 [&:has(.phx-change-loading)_[data-loading]]:flex"
            >
              <.button variant="dashed">
                <.icon name="hero-view-columns" class="icon" />
                <span class="hidden lg:inline ml-1">Columns</span>
              </.button>
              <:content>
                <div class="absolute inset-px bg-base/70 items-center justify-center hidden" data-loading>
                  <.loading class="text-foreground-softer" />
                </div>
                <h3 class="font-medium">Columns</h3>
                <.form :let={f} for={@columns_form} phx-change="update_columns">
                  <div class="flex items-center justify-between mt-3">
                    <.label for="invoice_number" class="text-foreground">Invoice #</.label>
                    <.switch
                      id="invoice_number"
                      field={f[:invoice_number]}
                      value={@visible_columns |> Enum.member?("invoice_number")}
                    />
                  </div>
                  <div class="flex items-center justify-between mt-3">
                    <.label for="due_date" class="text-foreground">Due Date</.label>
                    <.switch id="due_date" field={f[:due_date]} value={@visible_columns |> Enum.member?("due_date")} />
                  </div>
                  <div class="flex items-center justify-between mt-3">
                    <.label for="amount" class="text-foreground">Amount</.label>
                    <.switch id="amount" field={f[:amount]} value={@visible_columns |> Enum.member?("amount")} />
                  </div>
                  <div class="flex items-center justify-between mt-3">
                    <.label for="status" class="text-foreground">Status</.label>
                    <.switch id="status" field={f[:status]} value={@visible_columns |> Enum.member?("status")} />
                  </div>
                </.form>
              </:content>
            </.popover>

            <div class="ml-auto">
              <.button variant="dashed">
                <.icon name="hero-cog-6-tooth" class="icon" /> Settings
              </.button>
            </div>
          </div>

          <div class="overflow-x-auto">
            <.table>
              <.table_head class="text-foreground [&_th:first-child]:pl-4!">
                <:col :if={"invoice_number" in @visible_columns} class="py-3 border-r border-base">
                  <div class="inline-flex items-center gap-1">
                    <.icon name="hero-document-text" class="size-4.5 text-foreground-softer" /> Invoice #
                  </div>
                </:col>
                <:col class="py-3 w-1/3 border-r border-base">
                  <div class="flex items-center gap-1">
                    <.icon name="hero-user-circle" class="size-4.5 text-foreground-softer" /> Customer
                  </div>
                </:col>
                <:col :if={"due_date" in @visible_columns} class="py-3 border-r border-base">
                  <div class="flex items-center gap-1">
                    <.icon name="hero-calendar" class="size-4.5 text-foreground-softer" /> Due Date
                  </div>
                </:col>
                <:col :if={"amount" in @visible_columns} class="py-3 border-r border-base">
                  <div class="flex items-center gap-1">
                    <.icon name="hero-currency-dollar" class="size-4.5 text-foreground-softer" /> Amount
                  </div>
                </:col>
                <:col :if={"status" in @visible_columns} class="py-3 border-r border-base">
                  <div class="flex items-center gap-1">
                    <.icon name="hero-check-circle" class="size-4.5 text-foreground-softer" /> Status
                  </div>
                </:col>
              </.table_head>
              <.table_body class="text-foreground-soft">
                <.table_row
                  :for={invoice <- @invoices}
                  class="[&_td:first-child]:pl-4! [&_td:last-child]:pr-4! hover:bg-accent cursor-pointer group"
                  phx-click={
                    "invoice-details-sheet"
                    |> Fluxon.open_dialog()
                    |> JS.push("load_invoice_details", value: %{invoice_id: invoice.number})
                  }
                >
                  <:cell :if={"invoice_number" in @visible_columns} class="py-3 border-r border-base">
                    <div class="flex items-center">
                      {invoice.number}
                      <.icon name="hero-chevron-right" class="ml-auto size-4 text-zinc-500 invisible group-hover:visible" />
                    </div>
                  </:cell>
                  <:cell class="py-3 font-medium border-r border-base">
                    <div class="flex items-center gap-3">
                      <% colors = [
                        "bg-red-200/50",
                        "bg-blue-200/50",
                        "bg-green-200/50",
                        "bg-yellow-200/50",
                        "bg-purple-200/50",
                        "bg-pink-200/50",
                        "bg-indigo-200/50",
                        "bg-teal-200/50"
                      ]

                      color_index = :erlang.phash2(invoice.customer) |> rem(length(colors)) |> abs()
                      selected_color = Enum.at(colors, color_index) %>
                      <div class={"size-6 text-foreground-softer rounded-full flex items-center justify-center text-xs font-semibold #{selected_color}"}>
                        {String.at(invoice.customer, 0)}
                      </div>
                      {invoice.customer}
                    </div>
                  </:cell>
                  <:cell :if={"due_date" in @visible_columns} class="py-2 border-r border-base">
                    {invoice.due_date}
                  </:cell>
                  <:cell :if={"amount" in @visible_columns} class="py-2 border-r border-base">
                    {invoice.amount}
                  </:cell>
                  <:cell :if={"status" in @visible_columns} class="py-2 border-r border-base">
                    <% status_info = status_display(invoice.status) %>
                    <div class="flex items-center gap-x-2">
                      <.icon name={status_info.icon_name} class={"size-5 #{status_info.icon_class}"} />
                      <span>{status_info.label}</span>
                    </div>
                  </:cell>
                </.table_row>
              </.table_body>
            </.table>
            <div class="border-t border-b border-base border-dashed">
              <button class="w-full flex items-center justify-start gap-x-2 px-4 py-2 text-sm font-medium text-foreground hover:bg-accent/50 cursor-pointer">
                <div class="size-5 flex items-center justify-center rounded-full bg-primary text-foreground-primary">
                  <.icon name="hero-plus" class="size-4" />
                </div>
                New Invoice
              </button>
            </div>
          </div>

          <.sheet
            id="invoice-details-sheet"
            class="w-full max-w-md"
            placement="right"
            on_close={JS.push("clean_invoice_details")}
          >
            <div :if={!@invoice_details} class="space-y-10">
              <svg :for={_ <- 1..3} role="img" width="340" height="84" viewBox="0 0 340 84" preserveAspectRatio="none">
                <rect x="0" y="0" width="100%" height="100%" clip-path="url(#clip-path)" style='fill: url("#fill");'></rect>
                <defs>
                  <clipPath id="clip-path">
                    <rect x="0" y="0" rx="6" ry="6" width="67" height="11" />
                    <rect x="76" y="0" rx="6" ry="6" width="140" height="11" />
                    <rect x="127" y="48" rx="6" ry="6" width="53" height="11" />
                    <rect x="187" y="48" rx="6" ry="6" width="72" height="11" />
                    <rect x="18" y="48" rx="6" ry="6" width="100" height="11" />
                    <rect x="0" y="71" rx="6" ry="6" width="70" height="11" />
                    <rect x="73" y="71" rx="6" ry="6" width="120" height="11" />
                    <rect x="18" y="23" rx="6" ry="6" width="140" height="11" />
                    <rect x="166" y="23" rx="6" ry="6" width="103" height="11" />
                  </clipPath>
                  <linearGradient id="fill">
                    <stop offset="0.599964" stop-color="#f3f3f3" stop-opacity="1">
                      <animate
                        attributeName="offset"
                        values="-2; -2; 1"
                        keyTimes="0; 0.25; 1"
                        dur="2s"
                        repeatCount="indefinite"
                      >
                      </animate>
                    </stop>
                    <stop offset="1.59996" stop-color="#ecebeb" stop-opacity="1">
                      <animate
                        attributeName="offset"
                        values="-1; -1; 2"
                        keyTimes="0; 0.25; 1"
                        dur="2s"
                        repeatCount="indefinite"
                      >
                      </animate>
                    </stop>
                    <stop offset="2.59996" stop-color="#f3f3f3" stop-opacity="1">
                      <animate
                        attributeName="offset"
                        values="0; 0; 3"
                        keyTimes="0; 0.25; 1"
                        dur="2s"
                        repeatCount="indefinite"
                      >
                      </animate>
                    </stop>
                  </linearGradient>
                </defs>
              </svg>
            </div>

            <div :if={@invoice_details}>
              <h2 class="text-2xl font-semibold text-foreground">Invoice details</h2>
              <p class="text-foreground-softer">Details for invoice {@invoice_details.number}.</p>

              <dl class="mt-6 divide-y divide-base">
                <div class="py-4">
                  <dt class="text-sm font-medium text-foreground-softer">Customer</dt>
                  <dd class="mt-1 text-sm">{@invoice_details.customer}</dd>
                </div>
                <div class="py-4">
                  <dt class="text-sm font-medium text-foreground-softer">Invoice Number</dt>
                  <dd class="mt-1 text-sm">{@invoice_details.number}</dd>
                </div>
                <div class="py-4">
                  <dt class="text-sm font-medium text-foreground-softer">Due Date</dt>
                  <dd class="mt-1 text-sm">{@invoice_details.due_date}</dd>
                </div>
                <div class="py-4">
                  <dt class="text-sm font-medium text-foreground-softer">Amount</dt>
                  <dd class="mt-1 text-sm">{@invoice_details.amount}</dd>
                </div>
              </dl>

              <div class="flex items-center justify-end gap-2">
                <.button variant="solid" color="danger" phx-click={Fluxon.open_dialog("confirm-delete-modal")}>
                  <.icon name="hero-trash" class="icon" /> Delete
                </.button>
                <.button phx-click={Fluxon.open_dialog("edit-invoice-modal")}>
                  <.icon name="hero-pencil" class="icon" /> Edit
                </.button>
              </div>
            </div>

            <.modal :if={@invoice_details} id="confirm-delete-modal" class="w-full max-w-sm">
              <div class="flex flex-col items-center justify-center">
                <div class="rounded-full p-3 flex items-center bg-linear-to-b from-zinc-100 to-base">
                  <div class="border border-base rounded-full p-3 flex items-center bg-base">
                    <.icon name="hero-trash" class="size-6 text-red-600" />
                  </div>
                </div>

                <h3 class="font-medium text-lg text-foreground leading-snug mt-3">Delete Invoice</h3>
                <p class="text-foreground-softer text-center px-10">
                  Are you sure you want to delete the invoice <span class="font-bold"><%= @invoice_details.number %></span>?
                </p>
              </div>

              <div class="flex gap-3 *:flex-1 mt-6">
                <.button phx-click={Fluxon.close_dialog("confirm-delete-modal")}>Cancel</.button>
                <.button
                  color="danger"
                  variant="solid"
                  phx-click={
                    JS.push("delete_invoice", value: %{invoice_id: @invoice_details.number})
                    |> Fluxon.close_dialog("confirm-delete-modal")
                    |> Fluxon.close_dialog("invoice-details-sheet")
                  }
                >
                  Delete
                </.button>
              </div>
            </.modal>

            <.modal :if={Map.get(assigns, :edit_invoice_form)} id="edit-invoice-modal" class="w-full max-w-md p-0">
              <div class="p-6">
                <h2 class="text-2xl font-semibold text-foreground">Edit Invoice</h2>
                <p class="text-foreground-softer">Edit the invoice details.</p>
              </div>

              <.form for={@edit_invoice_form} phx-submit="update_invoice">
                <div class="p-6 pt-0 space-y-6">
                  <.input field={@edit_invoice_form[:number]} type="text" readonly label="Invoice #" />
                  <.input field={@edit_invoice_form[:customer]} type="text" label="Customer" />
                  <.input field={@edit_invoice_form[:amount]} type="number" label="Amount" />
                </div>

                <div class="px-6 py-4 bg-accent text-right rounded-b-base">
                  <.button type="submit" variant="solid" phx-disable-with="Updating...">Update</.button>
                </div>
              </.form>
            </.modal>
          </.sheet>

          <.modal id="new-invoice-modal" class="w-full max-w-md p-0 overflow-hidden">
            <div class="p-6">
              <h2 class="text-2xl font-semibold text-foreground">New Invoice</h2>
              <p class="text-foreground-softer">Create a new invoice.</p>
            </div>

            <.form for={@invoice_form} phx-submit="create_invoice">
              <div class="p-6 pt-0 space-y-6">
                <.input field={@invoice_form[:customer]} type="text" label="Customer" />
                <.input field={@invoice_form[:amount]} type="number" label="Amount" />
              </div>

              <div class="px-6 py-4 bg-zinc-100 text-right">
                <.button type="button" phx-click={Fluxon.close_dialog("new-invoice-modal")}>Cancel</.button>
                <.button type="submit" variant="solid" phx-disable-with="Creating...">Create</.button>
              </div>
            </.form>
          </.modal>
        </div>
      </main>
    </div>
    """
  end

  def handle_event("load_invoice_details", %{"invoice_id" => invoice_id}, socket) do
    invoice = Enum.find(socket.assigns.invoices, fn invoice -> invoice.number == invoice_id end)

    {:noreply,
     assign(socket,
       invoice_details: invoice,
       edit_invoice_form: to_form(Invoice.changeset(%Invoice{}, Map.from_struct(invoice)))
     )}
  end

  # The invoice details is cleaned when the dialog is closed.
  # This is to make sure the loading state shows again when the dialog is opened with a new invoice details.
  # This could eventually be improved by only show the loading state when a different invoice is opened.
  def handle_event("clean_invoice_details", _params, socket) do
    {:noreply, assign(socket, invoice_details: nil)}
  end

  def handle_event("delete_invoice", %{"invoice_id" => invoice_id}, socket) do
    invoice = Enum.find(socket.assigns.invoices, fn invoice -> invoice.number == invoice_id end)

    {:noreply, assign(socket, invoices: socket.assigns.invoices -- [invoice])}
  end

  def handle_event("update_invoice", %{"invoice" => invoice_params}, socket) do
    invoice_number = invoice_params["number"]
    original_invoice = Enum.find(socket.assigns.invoices, &(&1.number == invoice_number))

    case Invoice.changeset(original_invoice, invoice_params) |> Map.put(:action, :validate) do
      %{valid?: true} = changeset ->
        updated_invoice_data = Ecto.Changeset.apply_changes(changeset)

        updated_invoices =
          Enum.map(socket.assigns.invoices, fn
            %{number: ^invoice_number} -> updated_invoice_data
            invoice -> invoice
          end)

        {:noreply,
         socket
         |> assign(invoices: updated_invoices)
         |> assign(invoice_details: updated_invoice_data)
         |> assign(edit_invoice_form: to_form(changeset))
         |> Fluxon.close_dialog("edit-invoice-modal")}

      %{valid?: false} = changeset ->
        {:noreply, assign(socket, edit_invoice_form: to_form(changeset))}
    end
  end

  def handle_event("update_columns", columns, socket) do
    visible_columns =
      columns
      |> Map.keys()
      |> Enum.filter(&Phoenix.HTML.Form.normalize_value("checkbox", columns[&1]))

    {:noreply, assign(socket, columns_form: to_form(columns), visible_columns: visible_columns)}
  end

  def handle_event("create_invoice", %{"invoice" => invoice_params}, socket) do
    case Invoice.changeset(%Invoice{}, invoice_params) |> Map.put(:action, :validate) do
      %{valid?: true} = changeset ->
        applied_changes = Ecto.Changeset.apply_changes(changeset)
        current_count = Enum.count(socket.assigns.invoices)

        new_invoice = %Invoice{
          number: "INV-2024-#{String.pad_leading(Integer.to_string(current_count + 1), 3, "0")}",
          customer: applied_changes.customer,
          due_date: Date.utc_today() |> Date.add(30) |> Calendar.strftime("%b %d, %Y"),
          amount: Decimal.new(applied_changes.amount),
          status: :pending
        }

        {:noreply,
         socket
         |> assign(invoices: socket.assigns.invoices ++ [new_invoice])
         |> assign(invoice_form: to_form(Invoice.changeset(%Invoice{}, %{})))
         |> Fluxon.close_dialog("new-invoice-modal")}

      %{valid?: false} = changeset ->
        {:noreply, assign(socket, invoice_form: to_form(changeset))}
    end
  end

  def handle_event("sort_invoices", %{"sort" => sort}, socket) do
    sorted_invoices =
      case sort do
        "customer" -> Enum.sort_by(socket.assigns.invoices, & &1.customer, :asc)
        "status" -> Enum.sort_by(socket.assigns.invoices, & &1.status, :asc)
        "amount" -> Enum.sort_by(socket.assigns.invoices, & &1.amount, :asc)
        _ -> socket.assigns.invoices
      end

    {:noreply, assign(socket, invoices: sorted_invoices, sort: sort)}
  end

  # Helper function for status display
  defp status_display(status) do
    case status do
      :paid ->
        %{icon_name: "hero-check-circle-solid", icon_class: "text-green-600/60", label: "Paid"}

      :pending ->
        %{icon_name: "hero-clock-solid", icon_class: "text-yellow-500/60", label: "Pending"}

      :overdue ->
        %{icon_name: "hero-x-circle-solid", icon_class: "text-red-600/60", label: "Overdue"}
    end
  end
end
