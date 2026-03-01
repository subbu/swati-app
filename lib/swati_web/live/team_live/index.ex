defmodule SwatiWeb.TeamLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Accounts
  alias Swati.Accounts.Scope
  alias Swati.Tenancy.{Membership, Permissions, RoleTemplates}

  # ── Render ──────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-5">
        <%!-- Header --%>
        <div class="space-y-1">
          <h1 class="text-2xl font-semibold">Team</h1>
          <p class="text-sm text-base-content/70">Manage your team and what they can do.</p>
        </div>

        <%!-- Tab nav + action button --%>
        <div class="flex items-center justify-between">
          <nav class="flex items-center gap-1 text-sm">
            <.link
              :if={@can_manage_members}
              patch={~p"/settings/team"}
              class={nav_class(@tab == "members")}
            >
              Members
            </.link>
            <.link
              :if={@can_manage_roles}
              patch={~p"/settings/team?tab=roles"}
              class={nav_class(@tab == "roles")}
            >
              Roles
            </.link>
          </nav>

          <%= if @tab == "members" and @can_manage_members do %>
            <.button phx-click={Fluxon.open_dialog("invite-sheet")} size="sm">
              <.icon name="hero-plus" class="size-3.5 mr-1" /> Invite
            </.button>
          <% end %>
          <%= if @tab == "roles" and @can_manage_roles do %>
            <.button phx-click="show_templates" size="sm">
              <.icon name="hero-plus" class="size-3.5 mr-1" /> New role
            </.button>
          <% end %>
        </div>

        <%!-- Members tab --%>
        <%= if @tab == "members" and @can_manage_members do %>
          <div>
            <.table>
              <.table_head>
                <:col>Name</:col>
                <:col>Email</:col>
                <:col>Role</:col>
                <:col>Joined</:col>
                <:col class="w-10"></:col>
              </.table_head>
              <.table_body id="members" phx-update="stream">
                <.table_row id="members-empty" class="hidden only:table-row">
                  <:cell colspan="5" class="text-sm text-base-content/70 text-center py-4">
                    No members yet. Invite someone to get started.
                  </:cell>
                </.table_row>

                <.table_row :for={{id, membership} <- @streams.members} id={id}>
                  <:cell class="font-medium text-sm">
                    {Membership.display_name(membership)}
                    <span :if={membership.title} class="text-base-content/50 font-normal">
                      · {membership.title}
                    </span>
                  </:cell>
                  <:cell class="text-sm text-base-content/60">
                    {membership.user.email}
                  </:cell>
                  <:cell>
                    <%= if membership.user_id == @current_scope.user.id do %>
                      <.badge
                        color={if(membership.role.is_system, do: "primary", else: "info")}
                        variant="soft"
                        size="sm"
                      >
                        {membership.role.name}
                      </.badge>
                    <% else %>
                      <form phx-change="change_role" phx-value-membership-id={membership.id}>
                        <select name="role_id" class="select select-xs select-bordered">
                          <%= for {label, value} <- @role_options do %>
                            <option value={value} selected={membership.role_id == value}>
                              {label}
                            </option>
                          <% end %>
                        </select>
                      </form>
                    <% end %>
                  </:cell>
                  <:cell class="text-sm text-base-content/50">
                    {format_date(membership.inserted_at)}
                  </:cell>
                  <:cell>
                    <.dropdown
                      :if={membership.user_id != @current_scope.user.id}
                      placement="bottom-end"
                    >
                      <:toggle>
                        <button class="cursor-default p-1 rounded hover:bg-base-200">
                          <.icon name="hero-ellipsis-horizontal" class="size-4 text-base-content/50" />
                        </button>
                      </:toggle>
                      <.dropdown_button
                        phx-click="remove_member"
                        phx-value-membership-id={membership.id}
                        data-confirm="Remove this member? They will lose access."
                      >
                        <span class="text-error">Remove</span>
                      </.dropdown_button>
                    </.dropdown>
                  </:cell>
                </.table_row>
              </.table_body>
            </.table>
          </div>

          <%!-- Invite sheet --%>
          <.sheet id="invite-sheet" placement="right" class="w-full max-w-sm">
            <div class="p-5 space-y-5">
              <div>
                <h2 class="text-lg font-semibold">Invite a teammate</h2>
                <p class="text-sm text-base-content/70">They'll receive a magic link to join.</p>
              </div>

              <.form for={@form} id="invite-member-form" phx-submit="invite" class="space-y-4">
                <.input
                  field={@form[:email]}
                  type="email"
                  label="Email"
                  autocomplete="email"
                  required
                />
                <.select
                  field={@form[:role_id]}
                  label="Role"
                  options={@invite_role_options}
                  native
                />
                <.button type="submit" class="w-full" phx-disable-with="Sending invite...">
                  Send invite
                </.button>
              </.form>
            </div>
          </.sheet>
        <% end %>

        <%!-- Roles tab --%>
        <%= if @tab == "roles" and @can_manage_roles do %>
          <div class="rounded-xl border border-base-300 divide-y divide-base-300">
            <div
              :for={role <- @roles}
              class="flex items-center gap-4 py-3 px-5 hover:bg-base-200/50 transition-colors"
            >
              <div
                class="flex-1 flex items-center gap-4 min-w-0 cursor-pointer"
                phx-click="open_role_sheet"
                phx-value-role-id={role.id}
              >
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2">
                    <span class="text-sm font-medium">{role.name}</span>
                    <.badge :if={role.is_system} color="primary" variant="soft" size="xs">
                      System
                    </.badge>
                  </div>
                </div>
                <span class="text-xs text-base-content/50 tabular-nums whitespace-nowrap">
                  {length(role.permissions || [])}/{total_permissions()}
                </span>
                <div class="flex items-center gap-1.5">
                  <div :if={role.memberships != []} class="flex items-center -space-x-1.5">
                    <div
                      :for={m <- Enum.take(role.memberships, 3)}
                      class="size-5 rounded-full bg-base-300 flex items-center justify-center text-[10px] font-medium text-base-content/70 ring-1 ring-base-100"
                    >
                      {initial(m)}
                    </div>
                  </div>
                  <span class="text-xs text-base-content/50 whitespace-nowrap">
                    {member_count_text(length(role.memberships))}
                  </span>
                </div>
              </div>
              <%= unless role.is_system do %>
                <.dropdown placement="bottom-end">
                  <:toggle>
                    <button class="cursor-default p-1 rounded hover:bg-base-300">
                      <.icon name="hero-ellipsis-horizontal" class="size-4 text-base-content/50" />
                    </button>
                  </:toggle>
                  <.dropdown_button phx-click="open_role_sheet" phx-value-role-id={role.id}>
                    Edit
                  </.dropdown_button>
                  <.dropdown_button
                    phx-click="delete_role"
                    phx-value-role-id={role.id}
                    data-confirm="Delete this role? Members must be reassigned first."
                  >
                    <span class="text-error">Delete</span>
                  </.dropdown_button>
                </.dropdown>
              <% else %>
                <div class="w-[28px]"></div>
              <% end %>
            </div>

            <div :if={@roles == []} class="py-6 text-center text-sm text-base-content/60">
              No roles yet.
            </div>
          </div>

          <%!-- Template picker modal --%>
          <.modal
            id="template-picker"
            class="w-full max-w-md"
            open={@show_templates}
            on_close={JS.push("hide_templates")}
          >
            <div class="p-5 space-y-4">
              <div>
                <h2 class="text-lg font-semibold">Choose a template</h2>
                <p class="text-sm text-base-content/70">Pick a starting point, then customise.</p>
              </div>
              <div class="space-y-1">
                <%= for template <- @templates do %>
                  <button
                    phx-click="create_from_template"
                    phx-value-key={template.key}
                    class="flex flex-col w-full text-left rounded-lg px-3 py-2.5 hover:bg-base-200 transition-colors"
                  >
                    <span class="text-sm font-medium">{template.name}</span>
                    <span class="text-xs text-base-content/60">{template.description}</span>
                  </button>
                <% end %>
                <button
                  phx-click="create_blank"
                  class="flex flex-col w-full text-left rounded-lg border border-dashed border-base-300 px-3 py-2.5 hover:bg-base-200 transition-colors"
                >
                  <span class="text-sm font-medium">Blank role</span>
                  <span class="text-xs text-base-content/60">Start from scratch.</span>
                </button>
              </div>
            </div>
          </.modal>

          <%!-- Role editor sheet --%>
          <.sheet
            id="role-editor-sheet"
            placement="right"
            class="w-full max-w-md"
            open={@sheet_open}
            on_close={JS.push("close_role_sheet")}
          >
            <%= if @selected_role do %>
              <div class="p-5 space-y-5">
                <%!-- Name --%>
                <%= if @selected_role.is_system do %>
                  <div>
                    <h2 class="text-lg font-semibold">{@selected_role.name}</h2>
                    <p class="text-xs text-base-content/50">System role — all permissions granted.</p>
                  </div>
                <% else %>
                  <.form for={@name_form} phx-submit="save_name" phx-value-role-id={@selected_role.id}>
                    <div class="flex gap-2 items-end">
                      <div class="flex-1">
                        <.input field={@name_form[:name]} label="Role name" size="sm" />
                      </div>
                      <.button type="submit" size="sm" variant="outline" phx-disable-with="...">
                        Save
                      </.button>
                    </div>
                  </.form>
                <% end %>

                <%!-- Permissions --%>
                <div>
                  <%= for group <- @permission_groups do %>
                    <div class="mt-5 first:mt-0">
                      <h3 class="text-xs font-medium uppercase tracking-wide text-base-content/50 mb-2">
                        {group.label}
                      </h3>
                      <div class="space-y-0.5">
                        <%= for perm <- group.permissions do %>
                          <label class={[
                            "flex items-center gap-2.5 rounded px-2 py-1.5 text-sm",
                            if(@selected_role.is_system,
                              do: "opacity-50 cursor-not-allowed",
                              else: "hover:bg-base-200 cursor-pointer"
                            )
                          ]}>
                            <input
                              type="checkbox"
                              class="checkbox checkbox-xs checkbox-primary"
                              checked={Atom.to_string(perm.key) in (@selected_role.permissions || [])}
                              disabled={@selected_role.is_system}
                              phx-click="toggle_permission"
                              phx-value-role-id={@selected_role.id}
                              phx-value-permission={perm.key}
                            />
                            <span>{perm.label}</span>
                          </label>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>

                <%!-- Delete --%>
                <%= unless @selected_role.is_system do %>
                  <div class="pt-4 border-t border-base-300">
                    <button
                      phx-click="delete_role"
                      phx-value-role-id={@selected_role.id}
                      data-confirm="Delete this role? Members must be reassigned first."
                      class="text-sm text-error hover:underline"
                    >
                      Delete this role
                    </button>
                  </div>
                <% end %>
              </div>
            <% end %>
          </.sheet>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  # ── Lifecycle ───────────────────────────────────────────────────────

  @impl true
  def mount(_params, _session, socket) do
    can_members = Scope.can?(socket.assigns.current_scope, :manage_members)
    can_roles = Scope.can?(socket.assigns.current_scope, :manage_roles)

    if can_members or can_roles do
      {:ok,
       socket
       |> assign(:page_title, "Team")
       |> assign(:can_manage_members, can_members)
       |> assign(:can_manage_roles, can_roles)
       |> stream(:members, [])
       # Roles tab state
       |> assign(:roles, [])
       |> assign(:permission_groups, Permissions.groups())
       |> assign(:show_templates, false)
       |> assign(:templates, [])
       |> assign(:selected_role, nil)
       |> assign(:sheet_open, false)
       |> assign(:name_form, to_form(%{"name" => ""}, as: :role))
       # Members tab state
       |> assign(:role_options, [])
       |> assign(:invite_role_options, [])
       |> assign(:form, to_form(Accounts.change_membership_invite(), as: :membership_invite))}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to access this page.")
       |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tab = Map.get(params, "tab", "members")

    # If user doesn't have permission for the requested tab, fall back
    tab =
      cond do
        tab == "members" and socket.assigns.can_manage_members -> "members"
        tab == "roles" and socket.assigns.can_manage_roles -> "roles"
        socket.assigns.can_manage_members -> "members"
        socket.assigns.can_manage_roles -> "roles"
        true -> "members"
      end

    socket = assign(socket, :tab, tab)

    socket =
      case tab do
        "members" -> load_members(socket)
        "roles" -> load_roles(socket)
      end

    {:noreply, socket}
  end

  # ── Members events ──────────────────────────────────────────────────

  @impl true
  def handle_event("invite", %{"membership_invite" => params}, socket) do
    case Accounts.invite_member(
           socket.assigns.current_scope,
           params,
           &url(~p"/users/log-in/#{&1}")
         ) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invite sent.")
         |> load_members()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :membership_invite))}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "Not authorized.")}
    end
  end

  def handle_event(
        "change_role",
        %{"membership-id" => membership_id, "role_id" => role_id},
        socket
      ) do
    case Accounts.update_member_role(socket.assigns.current_scope, membership_id, role_id) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Role updated.") |> load_members()}

      {:error, :cannot_change_own_role} ->
        {:noreply, put_flash(socket, :error, "You cannot change your own role.")}

      {:error, :last_owner} ->
        {:noreply, put_flash(socket, :error, "Cannot change role of the last owner.")}

      {:error, :invalid_role} ->
        {:noreply, put_flash(socket, :error, "Invalid role selection.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update role.")}
    end
  end

  def handle_event("remove_member", %{"membership-id" => membership_id}, socket) do
    case Accounts.remove_member(socket.assigns.current_scope, membership_id) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Member removed.") |> load_members()}

      {:error, :cannot_remove_self} ->
        {:noreply, put_flash(socket, :error, "You cannot remove yourself.")}

      {:error, :last_owner} ->
        {:noreply, put_flash(socket, :error, "Cannot remove the last owner.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove member.")}
    end
  end

  # ── Roles events ────────────────────────────────────────────────────

  def handle_event("show_templates", _params, socket) do
    with :ok <- ensure_manage_roles(socket) do
      {:noreply,
       socket
       |> assign(:show_templates, true)
       |> assign(:templates, RoleTemplates.selectable())}
    else
      {:error, unauthorized_socket} -> {:noreply, unauthorized_socket}
    end
  end

  def handle_event("hide_templates", _params, socket) do
    with :ok <- ensure_manage_roles(socket) do
      {:noreply, assign(socket, :show_templates, false)}
    else
      {:error, unauthorized_socket} -> {:noreply, unauthorized_socket}
    end
  end

  def handle_event("create_from_template", %{"key" => key}, socket) do
    with :ok <- ensure_manage_roles(socket),
         {:ok, template_key} <- template_key_from_param(key) do
      tenant_id = socket.assigns.current_scope.tenant.id

      case Accounts.create_role_from_template(tenant_id, template_key) do
        {:ok, role} ->
          {:noreply,
           socket
           |> assign(:show_templates, false)
           |> put_flash(:info, "\"#{role.name}\" created.")
           |> load_roles()
           |> open_role_sheet(role.id)}

        {:error, %Ecto.Changeset{} = cs} ->
          msg = cs.errors |> Enum.map(fn {f, {m, _}} -> "#{f} #{m}" end) |> Enum.join(", ")
          {:noreply, socket |> assign(:show_templates, false) |> put_flash(:error, msg)}

        {:error, _} ->
          {:noreply,
           socket |> assign(:show_templates, false) |> put_flash(:error, "Could not create role.")}
      end
    else
      {:error, unauthorized_socket}
      when is_struct(unauthorized_socket, Phoenix.LiveView.Socket) ->
        {:noreply, unauthorized_socket}

      {:error, :invalid_template_key} ->
        {:noreply,
         socket |> assign(:show_templates, false) |> put_flash(:error, "Invalid template.")}
    end
  end

  def handle_event("create_blank", _params, socket) do
    with :ok <- ensure_manage_roles(socket) do
      tenant_id = socket.assigns.current_scope.tenant.id

      case Accounts.create_role(tenant_id, %{"name" => "New role", "permissions" => []}) do
        {:ok, role} ->
          {:noreply,
           socket
           |> assign(:show_templates, false)
           |> put_flash(:info, "Blank role created.")
           |> load_roles()
           |> open_role_sheet(role.id)}

        {:error, _} ->
          {:noreply,
           socket |> assign(:show_templates, false) |> put_flash(:error, "Could not create role.")}
      end
    else
      {:error, unauthorized_socket} -> {:noreply, unauthorized_socket}
    end
  end

  def handle_event("open_role_sheet", %{"role-id" => role_id}, socket) do
    with :ok <- ensure_manage_roles(socket) do
      {:noreply, open_role_sheet(socket, role_id)}
    else
      {:error, unauthorized_socket} -> {:noreply, unauthorized_socket}
    end
  end

  def handle_event("close_role_sheet", _params, socket) do
    with :ok <- ensure_manage_roles(socket) do
      {:noreply, assign(socket, sheet_open: false, selected_role: nil)}
    else
      {:error, unauthorized_socket} -> {:noreply, unauthorized_socket}
    end
  end

  def handle_event("save_name", %{"role" => %{"name" => name}, "role-id" => role_id}, socket) do
    with :ok <- ensure_manage_roles(socket) do
      tenant_id = socket.assigns.current_scope.tenant.id
      role = Accounts.get_role!(tenant_id, role_id)

      case Accounts.update_role(role, %{"name" => name}) do
        {:ok, _} ->
          {:noreply,
           socket |> put_flash(:info, "Role renamed.") |> load_roles() |> open_role_sheet(role_id)}

        {:error, %Ecto.Changeset{} = cs} ->
          msg = cs.errors |> Enum.map(fn {f, {m, _}} -> "#{f} #{m}" end) |> Enum.join(", ")
          {:noreply, put_flash(socket, :error, msg)}
      end
    else
      {:error, unauthorized_socket} -> {:noreply, unauthorized_socket}
    end
  end

  def handle_event("toggle_permission", %{"role-id" => role_id, "permission" => perm}, socket) do
    with :ok <- ensure_manage_roles(socket) do
      tenant_id = socket.assigns.current_scope.tenant.id
      role = Accounts.get_role!(tenant_id, role_id)
      current = role.permissions || []
      perm_str = to_string(perm)

      new_perms =
        if perm_str in current,
          do: List.delete(current, perm_str),
          else: [perm_str | current] |> Enum.sort()

      case Accounts.update_role(role, %{"permissions" => new_perms}) do
        {:ok, _} -> {:noreply, load_roles(socket) |> open_role_sheet(role_id)}
        {:error, _} -> {:noreply, put_flash(socket, :error, "Could not update permissions.")}
      end
    else
      {:error, unauthorized_socket} -> {:noreply, unauthorized_socket}
    end
  end

  def handle_event("delete_role", %{"role-id" => role_id}, socket) do
    with :ok <- ensure_manage_roles(socket) do
      tenant_id = socket.assigns.current_scope.tenant.id
      role = Accounts.get_role!(tenant_id, role_id)

      case Accounts.delete_role(role) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(sheet_open: false, selected_role: nil)
           |> put_flash(:info, "\"#{role.name}\" deleted.")
           |> load_roles()}

        {:error, :system_role} ->
          {:noreply, put_flash(socket, :error, "System roles cannot be deleted.")}

        {:error, :has_members} ->
          {:noreply, put_flash(socket, :error, "Reassign members before deleting this role.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not delete role.")}
      end
    else
      {:error, unauthorized_socket} -> {:noreply, unauthorized_socket}
    end
  end

  # ── Data loading ────────────────────────────────────────────────────

  defp load_members(socket) do
    tenant_id = socket.assigns.current_scope.tenant.id
    role_opts = Accounts.role_options(tenant_id)
    invite_role_opts = [{"Select a role", ""} | role_opts]

    case Accounts.list_members(socket.assigns.current_scope) do
      {:ok, members} ->
        socket
        |> assign(:role_options, role_opts)
        |> assign(:invite_role_options, invite_role_opts)
        |> assign(:form, to_form(Accounts.change_membership_invite(), as: :membership_invite))
        |> stream(:members, members, reset: true)

      {:error, _} ->
        socket |> stream(:members, [], reset: true)
    end
  end

  defp load_roles(socket) do
    tenant_id = socket.assigns.current_scope.tenant.id
    roles = Accounts.list_roles_with_members(tenant_id)

    # Refresh selected_role if sheet is open
    socket =
      case socket.assigns[:selected_role] do
        %{id: id} ->
          case Enum.find(roles, &(&1.id == id)) do
            nil -> assign(socket, selected_role: nil, sheet_open: false)
            role -> assign(socket, :selected_role, role)
          end

        _ ->
          socket
      end

    assign(socket, :roles, roles)
  end

  defp open_role_sheet(socket, role_id) do
    role = Enum.find(socket.assigns.roles, &(&1.id == role_id))

    if role do
      socket
      |> assign(:selected_role, role)
      |> assign(:sheet_open, true)
      |> assign(:name_form, to_form(%{"name" => role.name}, as: :role))
    else
      socket
    end
  end

  # ── Helpers ─────────────────────────────────────────────────────────

  defp nav_class(true),
    do: "px-3 py-1.5 rounded-base bg-accent text-foreground font-medium text-sm"

  defp nav_class(false),
    do: "px-3 py-1.5 rounded-base text-foreground-soft hover:bg-accent text-sm"

  defp member_count_text(0), do: "No members"
  defp member_count_text(1), do: "1 member"
  defp member_count_text(n) when is_integer(n), do: "#{n} members"

  defp initial(%{display_name: name}) when is_binary(name) and name != "",
    do: name |> String.first() |> String.upcase()

  defp initial(%{user: %{email: email}}) when is_binary(email),
    do: email |> String.first() |> String.upcase()

  defp initial(_), do: "?"

  defp total_permissions, do: length(Permissions.all())

  defp format_date(nil), do: "—"
  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %-d, %Y")

  defp ensure_manage_roles(socket) do
    if socket.assigns.can_manage_roles do
      :ok
    else
      {:error, put_flash(socket, :error, "Not authorized.")}
    end
  end

  defp template_key_from_param(key) when is_binary(key) do
    case Enum.find(RoleTemplates.selectable(), fn template ->
           Atom.to_string(template.key) == key
         end) do
      nil -> {:error, :invalid_template_key}
      template -> {:ok, template.key}
    end
  end

  defp template_key_from_param(_), do: {:error, :invalid_template_key}
end
