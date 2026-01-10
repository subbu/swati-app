# --- INFO ---
# This LiveView serves as a demonstration for the Fluxon UI components.
# For simplicity, all data fetching, state management, and business logic
# are handled directly within this module using hardcoded data (@products).
# In a real-world application, you would typically extract data handling
# into dedicated context modules and potentially use a database via Ecto.
# The primary goal here is to illustrate the integration and usage of
# Fluxon components in a LiveView setting, specifically for inventory management.
# -----------

defmodule MyAppWeb.InventoryManagementLive do
  use MyAppWeb, :live_view

  # Replace this static data with dynamic data from assigns in a real app
  @products [
    %{
      id: 1,
      last_updated: "Apr 07, 2025",
      stock_status: "In Stock",
      product_name: "Wireless Mouse",
      category: "Electronics",
      quantity: 150
    },
    %{
      id: 2,
      last_updated: "Apr 05, 2025",
      stock_status: "Low Stock",
      product_name: "Mechanical Keyboard",
      category: "Electronics",
      quantity: 15
    },
    %{
      id: 3,
      last_updated: "Mar 20, 2025",
      stock_status: "In Stock",
      product_name: "USB-C Hub",
      category: "Accessories",
      quantity: 75
    },
    %{
      id: 4,
      last_updated: "Apr 08, 2025",
      stock_status: "On Order",
      product_name: "27\" Monitor",
      category: "Electronics",
      quantity: 0
    },
    %{
      id: 5,
      last_updated: "Feb 15, 2025",
      stock_status: "Out of Stock",
      product_name: "Laptop Stand",
      category: "Accessories",
      quantity: 0
    }
  ]

  def mount(_, _, socket) do
    {:ok, assign(socket, products: @products)}
  end

  def render(assigns) do
    ~H"""
    <script>
      // --- INFO ---
      // In a production Phoenix application, this JavaScript logic should ideally
      // reside in your `assets/js/app.js` file or within a dedicated Phoenix Hook.
      // Placing it directly in the template is done here for demo simplicity.
      // ------------
      const updateTableSelectionUI = (table) => {
        const selectAllCheckbox = table.querySelector('thead input[name="select-all"]');
        const rowCheckboxes = table.querySelectorAll('tbody input[type="checkbox"][name^="select-"]');
        const selectedCountSpan = document.querySelector('[data-selected-count-number]');

        const totalRowCount = rowCheckboxes.length;
        const selectedRowCount = Array.from(rowCheckboxes).filter(checkbox => checkbox.checked).length;

        selectedCountSpan.textContent = selectedRowCount;

        if (selectAllCheckbox) {
          selectAllCheckbox.checked = totalRowCount > 0 && selectedRowCount === totalRowCount;
          selectAllCheckbox.indeterminate = selectedRowCount > 0 && selectedRowCount < totalRowCount;
        }

        const commandAttribute = selectedRowCount > 0 ? 'data-js-has-checked' : 'data-js-has-no-checked';
        const commandToExec = table.getAttribute(commandAttribute);
        window.liveSocket.execJS(table, commandToExec);
      };

      document.addEventListener('table:select-all', (event) => {
        const checkbox = event.target;
        const table = checkbox.closest('table');

        const isChecked = checkbox.checked;
        table.querySelectorAll('tbody input[type="checkbox"][name^="select-"]').forEach(rowCheckbox => {
          rowCheckbox.checked = isChecked;
        });

        updateTableSelectionUI(table);
      });

      document.addEventListener('table:select-row', (event) => {
        const table = event.target.closest('table');

        updateTableSelectionUI(table);
      });
    </script>

    <.sheet id="mobile-sidebar-nav" placement="left" class="w-full max-w-xs">
      <div class="flex mb-6 shrink-0 items-center">
        <img src="https://fluxonui.com/images/logos/1.svg" alt="Fluxon" class="h-7 w-auto" />
      </div>

      <.navlist heading="Overview">
        <.navlink navigate="/dashboard">
          <.icon name="hero-squares-2x2" class="icon" /> Dashboard
        </.navlink>
        <.navlink navigate="/reports">
          <.icon name="hero-chart-bar" class="icon" /> Reports
        </.navlink>
      </.navlist>

      <.navlist heading="Management">
        <.navlink navigate="/products">
          <.icon name="hero-archive-box" class="icon" /> Products
        </.navlink>
        <.navlink navigate="/suppliers">
          <.icon name="hero-building-storefront" class="icon" /> Suppliers
        </.navlink>
        <.navlink navigate="/orders">
          <.icon name="hero-truck" class="icon" /> Orders
        </.navlink>
        <.navlink navigate="/settings">
          <.icon name="hero-cog-6-tooth" class="icon" /> Settings
        </.navlink>
      </.navlist>

      <.navlist heading="Setup">
        <.navlink navigate="/users">
          <.icon name="hero-users" class="icon" /> User Management
        </.navlink>
        <.navlink navigate="/import-export">
          <.icon name="hero-arrow-path" class="icon" /> Data Import/Export
        </.navlink>
      </.navlist>
    </.sheet>

    <.modal id="add-product-modal">
      <h2 class="text-lg font-medium text-foreground">Add Product</h2>
      <p class="text-sm text-foreground-softest mb-4">
        Enter the details for the new product below.
      </p>
      <.form :let={f} for={to_form(%{})} phx-change="validate_add_product" phx-submit="save_add_product" class="space-y-4">
        <.input autofocus field={f[:product_name]} label="Product name" placeholder="e.g. Wireless Mouse" />

        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <.select
            field={f[:category]}
            label="Category"
            placeholder="e.g. Electronics"
            options={[
              {"Electronics", "electronics"},
              {"Furniture", "furniture"},
              {"Office Supplies", "office_supplies"},
              {"Accessories", "accessories"},
              {"Other", "other"}
            ]}
          />

          <.select
            field={f[:stock_status]}
            label="Stock Status"
            placeholder="e.g. In Stock"
            options={[
              {"In Stock", "in_stock"},
              {"Low Stock", "low_stock"},
              {"Out of Stock", "out_of_stock"},
              {"On Order", "on_order"}
            ]}
          />
        </div>

        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <.input field={f[:price]} label="Price" type="number" step="0.01" placeholder="e.g. 29.99" />
          <.input field={f[:quantity]} label="Quantity" type="number" placeholder="e.g. 150" />
        </div>

        <.textarea field={f[:description]} label="Description" placeholder="Enter a brief description" />

        <div class="mt-6 flex justify-end gap-3">
          <.button type="button" phx-click={Fluxon.close_dialog("add-product-modal")} variant="ghost">Cancel</.button>
          <.button
            variant="solid"
            type="submit"
            phx-disable-with="Saving..."
            phx-click={Fluxon.close_dialog("add-product-modal")}
          >
            Save Product
          </.button>
        </div>
      </.form>
    </.modal>

    <.modal id="view-product-modal" placement="full-right" class="w-full max-w-md">
      <header class="flex items-start justify-between pr-6">
        <div>
          <h2 class="text-lg font-medium text-foreground">Wireless Mouse</h2>
          <p class="text-sm text-foreground-softest">
            Electronics &bull; WM-1001
          </p>
        </div>

        <.badge color="success">In Stock</.badge>
      </header>

      <.separator class="my-4 -mx-6" />

      <.tabs>
        <.tabs_list active_tab="details" class="px-4 -mx-6">
          <:tab name="details">Details</:tab>
          <:tab name="history">History</:tab>
        </.tabs_list>

        <.tabs_panel name="details" active>
          <div class="space-y-4 mt-4">
            <div class="grid grid-cols-1 gap-x-4 gap-y-6 sm:grid-cols-2">
              <div>
                <dt class="text-sm font-medium text-foreground-softest">Price</dt>
                <dd class="mt-1 text-sm text-foreground">$29.99</dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-foreground-softest">Category</dt>
                <dd class="mt-1 text-sm text-foreground">Electronics</dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-foreground-softest">SKU</dt>
                <dd class="mt-1 text-sm text-foreground">WM-1001</dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-foreground-softest">Supplier</dt>
                <dd class="mt-1 text-sm text-foreground">TechGadgets Inc.</dd>
              </div>
            </div>
            <div>
              <dt class="text-sm font-medium text-foreground-softest">Description</dt>
              <dd class="mt-1 text-sm text-foreground">
                A reliable wireless mouse with ergonomic design, perfect for everyday use. Long battery life and precise tracking.
              </dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-foreground-softest">Last Updated</dt>
              <dd class="mt-1 text-sm text-foreground">April 7, 2025</dd>
            </div>
          </div>
        </.tabs_panel>

        <.tabs_panel name="history">
          <div class="py-6 pl-2">
            <ul role="list">
              <li class="relative border-l border-base pb-6">
                <div class="absolute -left-[13px] top-0 flex size-6 items-center justify-center bg-base">
                  <.icon name="hero-check-circle" class="size-5 text-green-600" aria-label="Completed" />
                </div>
                <div class="ml-6">
                  <p class="py-0.5 text-sm leading-5 text-foreground-softest">
                    <span class="font-medium text-foreground">Admin User</span> added the product.
                  </p>
                  <time
                    datetime="2025-03-15T10:00"
                    class="flex-none py-0.5 text-xs leading-5 text-foreground-softest"
                    title="March 15, 2025, 10:00 AM"
                  >
                    Mar 15, 2025
                  </time>
                </div>
              </li>

              <li class="relative border-l border-base pb-6">
                <div class="absolute -left-[13px] top-0 flex size-6 items-center justify-center bg-base">
                  <.icon name="hero-arrow-up-circle" class="size-5 text-blue-600" aria-label="Stock Increase" />
                </div>
                <div class="ml-6">
                  <p class="flex-auto py-0.5 text-sm leading-5 text-foreground-softest">
                    Stock increased by <span class="font-medium text-foreground">100 units</span>
                    via <a href="#" class="font-medium text-foreground hover:text-foreground-softest">PO #12345</a>.
                  </p>
                  <time
                    datetime="2025-04-01T09:30"
                    class="flex-none py-0.5 text-xs leading-5 text-foreground-softest"
                    title="April 1, 2025, 9:30 AM"
                  >
                    Apr 1, 2025
                  </time>
                </div>
              </li>

              <li class="relative border-l border-base pb-6">
                <div class="absolute -left-[13px] top-0 flex size-6 items-center justify-center bg-base">
                  <.icon name="hero-currency-dollar" class="size-5 text-foreground-softest" aria-label="Price Update" />
                </div>
                <div class="ml-6">
                  <p class="flex-auto py-0.5 text-sm leading-5 text-foreground-softest">
                    Price updated from <span class="font-medium text-foreground">$25.99</span>
                    to <span class="font-medium text-foreground">29.99</span>.
                  </p>
                  <time
                    datetime="2025-04-05T14:15"
                    class="flex-none py-0.5 text-xs leading-5 text-foreground-softest"
                    title="April 5, 2025, 2:15 PM"
                  >
                    Apr 5, 2025
                  </time>
                </div>
              </li>

              <li class="relative border-l border-base pb-6">
                <div class="absolute -left-[13px] top-0 flex size-6 items-center justify-center bg-base">
                  <.icon name="hero-arrow-down-circle" class="size-5 text-red-600" aria-label="Stock Decrease" />
                </div>
                <div class="ml-6">
                  <p class="flex-auto py-0.5 text-sm leading-5 text-foreground-softest">
                    Stock decreased by <span class="font-medium text-foreground">10 units</span>
                    (<a href="#" class="font-medium text-foreground hover:text-foreground-softest">Order #6789</a>).
                  </p>
                  <time
                    datetime="2025-04-06T11:00"
                    class="flex-none py-0.5 text-xs leading-5 text-foreground-softest"
                    title="April 6, 2025, 11:00 AM"
                  >
                    3d ago
                  </time>
                </div>
              </li>

              <li class="relative border-l border-base pb-6">
                <div class="absolute -left-[13px] top-0 flex size-6 items-center justify-center bg-base">
                  <.icon name="hero-chat-bubble-left-ellipsis" class="size-5 text-foreground-softest" aria-label="Comment" />
                </div>
                <div class="ml-6">
                  <div class="py-0.5 text-sm leading-5 text-foreground-softest">
                    <a href="#" class="font-medium text-foreground hover:text-foreground-softest">
                      Jane Doe
                    </a>
                    commented
                  </div>
                  <time
                    datetime="2025-04-07T11:00"
                    class="flex-none py-0.5 text-xs leading-5 text-foreground-softest"
                    title="April 7, 2025, 11:00 AM"
                  >
                    2d ago
                  </time>
                  <div class="mt-2 rounded-base p-3 text-sm leading-5 bg-base shadow-base">
                    <p class="text-foreground-softest">Updated the product description with new features.</p>
                  </div>
                </div>
              </li>

              <li class="relative border-l border-base">
                <div class="absolute -left-[13px] top-0 flex size-6 items-center justify-center bg-base">
                  <.icon name="hero-exclamation-circle" class="size-5 text-yellow-600" aria-label="Warning" />
                </div>
                <div class="ml-6">
                  <p class="py-0.5 text-sm leading-5 text-foreground-softest">
                    Status changed to <span class="font-medium text-yellow-600">Low Stock</span>.
                  </p>
                  <time
                    datetime="2025-04-08T16:30"
                    class="flex-none py-0.5 text-xs leading-5 text-foreground-softest"
                    title="April 8, 2025, 4:30 PM"
                  >
                    5h ago
                  </time>
                </div>
              </li>
            </ul>
          </div>
        </.tabs_panel>
      </.tabs>
    </.modal>

    <div class="bg-accent/50">
      <div class="mx-auto max-w-screen-2xl min-h-screen flex flex-col">
        <nav class="lg:w-64 hidden overflow-x-hidden lg:fixed lg:inset-y-0 lg:z-50 lg:flex lg:flex-col">
          <aside class="flex flex-1 flex-col overflow-y-auto p-6">
            <div class="flex shrink-0 items-center mb-8 gap-2">
              <img src="https://fluxonui.com/images/logos/1.svg" alt="Fluxon" class="h-6 w-auto" />
              <span class="text-lg font-extrabold text-foreground">AcmeCo.</span>
            </div>

            <.navlist heading="Overview">
              <.navlink navigate="/dashboard">
                <.icon name="hero-squares-2x2" class="icon" /> Dashboard
              </.navlink>
              <.navlink navigate="/reports">
                <.icon name="hero-chart-bar" class="icon" /> Reports
              </.navlink>
            </.navlist>

            <.navlist heading="Management">
              <.navlink navigate="/products" class="text-foreground" active>
                <.icon name="hero-archive-box" class="icon" /> Products
              </.navlink>
              <.navlink navigate="/suppliers">
                <.icon name="hero-building-storefront" class="icon" /> Suppliers
              </.navlink>
              <.navlink navigate="/orders">
                <.icon name="hero-truck" class="icon" /> Orders
              </.navlink>
              <.navlink navigate="/settings">
                <.icon name="hero-cog-6-tooth" class="icon" /> Settings
              </.navlink>
            </.navlist>

            <.navlist heading="Setup">
              <.navlink navigate="/users">
                <.icon name="hero-users" class="icon" /> User Management
              </.navlink>
              <.navlink navigate="/import-export">
                <.icon name="hero-arrow-path" class="icon" /> Data Import/Export
              </.navlink>
            </.navlist>
          </aside>

          <div class="max-lg:hidden flex flex-col border-base p-4 pt-0">
            <.dropdown class="w-56">
              <:toggle class="w-full">
                <button class="cursor-pointer text-left flex in-aria-expanded:bg-accent hover:bg-accent w-full items-center gap-3 rounded-base px-2 py-1.5">
                  <div class="flex min-w-0 items-center gap-3">
                    <div class="size-9 shrink-0 rounded-full overflow-hidden border border-base shadow">
                      <img class="size-full" src="https://i.pravatar.cc/150?u=John+Doe" alt="John Doe" />
                    </div>

                    <div class="min-w-0">
                      <span class="block truncate text-sm font-medium text-foreground">
                        John Doe
                      </span>
                      <span class="block truncate text-xs font-normal text-foreground-softer">
                        john@example.com
                      </span>
                    </div>
                  </div>

                  <.icon name="hero-chevron-up-down" class="size-4 text-foreground-softer ml-auto" />
                </button>
              </:toggle>

              <.dropdown_link navigate="/profile">
                <.icon name="hero-user-circle" class="icon" /> Your profile
              </.dropdown_link>
              <.dropdown_link navigate="/settings">
                <.icon name="hero-cog-6-tooth" class="icon text-foreground-softest" /> Account Settings
              </.dropdown_link>
              <.dropdown_link navigate="/notifications">
                <.icon name="hero-bell" class="icon text-foreground-softest" /> Notifications
              </.dropdown_link>

              <.dropdown_separator />

              <.dropdown_link navigate="/upgrade">
                <.icon name="hero-star-solid" class="icon text-orange-600!" /> Upgrade Plan
                <.badge color="warning" class="ml-auto font-medium">20% off</.badge>
              </.dropdown_link>

              <.dropdown_link navigate="/help">
                <.icon name="hero-question-mark-circle" class="icon text-foreground-softest" /> Help Center
              </.dropdown_link>

              <.dropdown_separator />

              <.dropdown_link navigate="/signout" class="text-red-600 data-highlighted:bg-red-700/10">
                <.icon name="hero-arrow-right-on-rectangle" class="icon text-red-500" /> Sign out
              </.dropdown_link>
            </.dropdown>
          </div>
        </nav>

        <header class="flex items-center px-4 lg:hidden border-b border-base bg-base">
          <div class="py-2.5">
            <button
              phx-click={Fluxon.open_dialog("mobile-sidebar-nav")}
              class="cursor-pointer relative flex min-w-0 items-center gap-3 rounded-base p-2"
            >
              <.icon name="hero-bars-3" class="size-6" />
            </button>
          </div>
          <div class="min-w-0 flex-1">
            <nav class="flex flex-1 items-center gap-4 py-2.5">
              <div class="flex items-center gap-3 ml-auto">
                <.dropdown placement="bottom-end">
                  <:toggle class="w-full flex items-center">
                    <button class="cursor-pointer size-9 rounded-base overflow-hidden">
                      <img class="size-full" src="https://i.pravatar.cc/150?u=John+Doe" alt="John Doe" />
                    </button>
                  </:toggle>

                  <.dropdown_custom class="flex items-center p-3">
                    <img class="size-10 rounded-base" src="https://i.pravatar.cc/150?u=John+Doe" alt="John Doe" />
                    <div class="flex flex-col ml-3">
                      <span class="text-sm font-medium text-foreground">John Doe</span>
                      <span class="text-xs text-foreground-softest">john@example.com</span>
                    </div>
                  </.dropdown_custom>

                  <.dropdown_separator />

                  <.dropdown_link navigate="/profile">
                    <.icon name="hero-user-circle" class="icon" /> Your profile
                  </.dropdown_link>
                  <.dropdown_link navigate="/settings">
                    <.icon name="hero-cog-6-tooth" class="icon" /> Account Settings
                  </.dropdown_link>
                  <.dropdown_link navigate="/notifications">
                    <.icon name="hero-bell" class="icon" /> Notifications
                  </.dropdown_link>

                  <.dropdown_separator />

                  <.dropdown_link navigate="/upgrade">
                    <.icon name="hero-star" class="icon" /> Upgrade Plan
                    <.badge color="warning" class="ml-auto">20% off</.badge>
                  </.dropdown_link>

                  <.dropdown_link navigate="/help">
                    <.icon name="hero-question-mark-circle" class="icon" /> Help Center
                  </.dropdown_link>

                  <.dropdown_separator />

                  <.dropdown_link navigate="/signout" class="text-red-600">
                    <.icon name="hero-arrow-right-on-rectangle" class="icon" /> Sign out
                  </.dropdown_link>
                </.dropdown>
              </div>
            </nav>
          </div>
        </header>

        <main class="flex flex-1 flex-col lg:min-w-0 p-2 lg:pl-64">
          <div class="grow p-6 rounded-base bg-base border border-base">
            <header class="flex items-center justify-between mb-4">
              <h1 class="text-xl font-medium mb-4">Products</h1>
              <.button phx-click={Fluxon.open_dialog("add-product-modal")}>
                <.icon name="hero-plus" class="icon" /> Add
              </.button>
            </header>
            <div class="overflow-x-auto">
              <.table>
                <colgroup>
                  <col class="w-12" />
                  <col />
                  <col />
                  <col />
                  <col />
                  <col />
                  <col class="w-20" />
                </colgroup>
                <.table_head>
                  <:col class="py-2 pl-4!">
                    <.checkbox name="select-all" data-element="select-all-checkbox" />
                  </:col>
                  <:col class="py-2" phx-click="sort" phx-value-column="last_updated">
                    <button class="-mx-2 cursor-pointer flex items-center gap-0.5 px-2 py-1 rounded-base hover:bg-accent">
                      Last Updated
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" class="size-4 text-foreground-softest">
                        <path fill="currentColor" d="M11 7H5l3-4z" />
                        <path fill="currentColor" d="M5 9h6l-3 4z" />
                      </svg>
                    </button>
                  </:col>
                  <:col class="py-2" phx-click="sort" phx-value-column="status">
                    <button class="-mx-2 cursor-pointer flex items-center gap-0.5 px-2 py-1 rounded-base hover:bg-accent">
                      Status
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" class="size-4 text-foreground-softest">
                        <path fill="currentColor" d="M11 7H5l3-4z" />
                        <path fill="currentColor" d="M5 9h6l-3 4z" />
                      </svg>
                    </button>
                  </:col>
                  <:col class="py-2" phx-click="sort" phx-value-column="product_name">
                    <button class="-mx-2 cursor-pointer flex items-center gap-0.5 px-2 py-1 rounded-base hover:bg-accent">
                      Product Name
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" class="size-4 text-foreground-softest">
                        <path fill="currentColor" d="M11 7H5l3-4z" />
                        <path fill="currentColor" d="M5 9h6l-3 4z" />
                      </svg>
                    </button>
                  </:col>
                  <:col class="py-2" phx-click="sort" phx-value-column="category">
                    <button class="-mx-2 cursor-pointer flex items-center gap-0.5 px-2 py-1 rounded-base hover:bg-accent">
                      Category
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" class="size-4 text-foreground-softest">
                        <path fill="currentColor" d="M11 7H5l3-4z" />
                        <path fill="currentColor" d="M5 9h6l-3 4z" />
                      </svg>
                    </button>
                  </:col>
                  <:col class="py-2 flex justify-center" phx-click="sort" phx-value-column="quantity">
                    <button class="-mx-2 cursor-pointer flex items-center gap-0.5 px-2 py-1 rounded-base hover:bg-accent">
                      Quantity
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" class="size-4 text-foreground-softest">
                        <path fill="currentColor" d="M11 7H5l3-4z" />
                        <path fill="currentColor" d="M5 9h6l-3 4z" />
                      </svg>
                    </button>
                  </:col>
                  <:col class="py-2"></:col>
                </.table_head>
                <.table_body
                  id="products-table"
                  data-js-has-checked={
                    JS.show(
                      to: "#action-dialog",
                      transition:
                        {"transition ease-out duration-200", "opacity-0 translate-y-4", "opacity-100 translate-y-0"}
                    )
                  }
                  data-js-has-no-checked={
                    JS.hide(
                      to: "#action-dialog",
                      transition:
                        {"transition ease-in duration-150", "opacity-100 translate-y-0", "opacity-0 translate-y-4"}
                    )
                  }
                >
                  <.table_row :for={product <- @products} class="hover:bg-accent/50 has-checked:bg-accent">
                    <:cell class="pl-4! py-2 align-middle relative group">
                      <.checkbox
                        name={"select-#{product.id}"}
                        phx-click={JS.dispatch("products-table:select", to: "#products-table")}
                        data-element="product-checkbox"
                      />
                      <span class="hidden h-full absolute inset-y-0 left-0 w-[2px] bg-primary group-has-checked:block">
                      </span>
                    </:cell>
                    <:cell class="py-2 align-middle">{product.last_updated}</:cell>
                    <:cell class="py-2 align-middle">
                      <.badge color={
                        case product.stock_status do
                          "In Stock" -> "success"
                          "Low Stock" -> "warning"
                          "On Order" -> "info"
                          "Out of Stock" -> "danger"
                          "Discontinued" -> "primary"
                          _ -> "primary"
                        end
                      }>
                        {product.stock_status}
                      </.badge>
                    </:cell>
                    <:cell class="py-2 align-middle font-medium text-foreground">
                      {product.product_name}
                    </:cell>
                    <:cell class="py-2 align-middle">{product.category}</:cell>
                    <:cell class="py-2 align-middle text-center">{product.quantity}</:cell>
                    <:cell class="py-2 align-middle text-center">
                      <.button variant="ghost" size="icon-sm" phx-click={Fluxon.open_dialog("view-product-modal")}>
                        <.icon name="hero-eye" class="icon" />
                      </.button>
                    </:cell>
                  </.table_row>
                </.table_body>
              </.table>
            </div>
          </div>
        </main>
      </div>
    </div>

    <div id="action-dialog" role="dialog" tabindex="-1" class="hidden fixed bottom-4 left-1/2 -translate-x-1/2 z-50">
      <div class="relative flex items-center rounded-base shadow-base bg-primary">
        <div
          data-element="selected-count-display"
          class="px-3 py-2.5 text-base sm:text-sm tabular-nums text-foreground-primary opacity-70 whitespace-nowrap"
        >
          <span data-element="selected-count-number" class="text-foreground-primary opacity-100">1</span> selected
        </div>
        <div class="h-4 border-l border-base/30"></div>
        <div class="flex items-center gap-x-2 p-1 text-base font-medium text-foreground-primary outline-none transition focus:z-10 sm:text-sm sm:last-of-type:-mr-1">
          <button
            type="button"
            class="flex items-center gap-x-2 rounded-base px-1.5 py-1 hover:bg-base/10 focus-visible:bg-base/10 focus-visible:hover:bg-base/10 disabled:text-foreground-primary disabled:opacity-50 outline-offset-2 outline-0 focus-visible:outline-2 outline-blue-500 text-foreground-primary"
          >
            <span class="whitespace-nowrap">Edit</span>
            <span class="hidden h-5 select-none items-center justify-center rounded-md bg-base/10 border border-base/50 px-1.5 font-mono text-xs text-foreground-primary opacity-70 transition sm:flex">
              E
            </span>
          </button>
        </div>
        <div class="h-4 border-l border-base/30"></div>
        <div class="flex items-center gap-x-2 p-1 text-base font-medium text-foreground-primary outline-none transition focus:z-10 sm:text-sm sm:last-of-type:-mr-1">
          <button
            type="button"
            class="flex items-center gap-x-2 rounded-base px-1.5 py-1 hover:bg-base/10 focus-visible:bg-base/10 focus-visible:hover:bg-base/10 disabled:text-foreground-primary disabled:opacity-50 outline-offset-2 outline-0 focus-visible:outline-2 outline-blue-500 text-foreground-primary"
          >
            <span class="whitespace-nowrap">Delete</span>
            <span class="hidden h-5 select-none items-center justify-center rounded-md bg-base/10 border border-base/50 px-1.5 font-mono text-xs text-foreground-primary opacity-70 transition sm:flex">
              D
            </span>
          </button>
        </div>
        <div class="h-4 border-l border-base/30"></div>
        <div class="flex items-center gap-x-2 p-1 text-base font-medium text-foreground-primary outline-none transition focus:z-10 sm:text-sm sm:last-of-type:-mr-1">
          <button
            type="button"
            class="flex items-center gap-x-2 rounded-base px-1.5 py-1 hover:bg-base/10 focus-visible:bg-base/10 focus-visible:hover:bg-base/10 disabled:text-foreground-primary disabled:opacity-50 outline-offset-2 outline-0 focus-visible:outline-2 outline-blue-500 text-foreground-primary"
          >
            <span class="whitespace-nowrap">Reset</span>
            <span class="hidden h-5 select-none items-center justify-center rounded-md bg-base/10 border border-base/50 px-1.5 font-mono text-xs text-foreground-primary opacity-70 transition sm:flex">
              ESC
            </span>
          </button>
        </div>
      </div>
    </div>
    """
  end
end
