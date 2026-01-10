defmodule SwatiWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use SwatiWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <%= if @current_scope do %>
      <% user = @current_scope.user %>
      <% tenant = @current_scope.tenant %>
      <% avatar_text = if user && user.email, do: user.email, else: "User" %>
      <% avatar_url = "https://ui-avatars.com/api/?name=#{URI.encode_www_form(avatar_text)}" %>

      <.sheet id="mobile-sidebar-nav" placement="left" class="w-full max-w-xs">
        <div class="flex mb-6 shrink-0 items-center gap-2">
          <.logo_with_tiles id="mobile-logo" img_class="h-12 w-auto" class="shrink-0" />
        </div>

        <.navlist heading="Workspace">
          <.navlink navigate={~p"/onboarding"}>
            <.icon
              name="hero-arrow-trending-up"
              class="size-5 text-foreground-softer group-hover:text-foreground"
            /> Onboarding
          </.navlink>
          <.navlink navigate={~p"/dashboard"}>
            <.icon
              name="hero-chart-bar-square"
              class="size-5 text-foreground-softer group-hover:text-foreground"
            /> Dashboard
          </.navlink>
          <.navlink navigate={~p"/agents"}>
            <.icon
              name="hero-user-circle"
              class="size-5 text-foreground-softer group-hover:text-foreground"
            /> Agents
          </.navlink>
          <.navlink navigate={~p"/integrations"}>
            <.icon
              name="hero-wrench-screwdriver"
              class="size-5 text-foreground-softer group-hover:text-foreground"
            /> Integrations
          </.navlink>
          <.navlink navigate={~p"/numbers"}>
            <.icon
              name="hero-hashtag"
              class="size-5 text-foreground-softer group-hover:text-foreground"
            /> Numbers
          </.navlink>
          <.navlink navigate={~p"/calls"}>
            <.icon
              name="hero-phone"
              class="size-5 text-foreground-softer group-hover:text-foreground"
            /> Calls
          </.navlink>
        </.navlist>

        <.navlist heading="Organization">
          <.navlink navigate={~p"/settings/members"}>
            <.icon
              name="hero-user-group"
              class="size-5 text-foreground-softer group-hover:text-foreground"
            /> Members
          </.navlink>
          <.navlink navigate={~p"/users/settings"}>
            <.icon
              name="hero-cog-6-tooth"
              class="size-5 text-foreground-softer group-hover:text-foreground"
            /> Settings
          </.navlink>
        </.navlist>

        <.navlist class="mt-auto!">
          <.navlink href={~p"/users/log-out"} method="delete">
            <.icon
              name="hero-arrow-right-on-rectangle"
              class="size-5 text-foreground-softer group-hover:text-foreground"
            /> Sign out
          </.navlink>
        </.navlist>
      </.sheet>

      <div class="relative isolate flex min-h-svh w-full max-md:flex-col bg-accent/50">
        <div class="fixed inset-y-0 left-0 w-64 max-md:hidden">
          <div class="flex h-full flex-col">
            <div class="flex flex-1 flex-col overflow-y-auto p-6">
              <div class="flex shrink-0 items-center mb-8 gap-2">
                <.logo_with_tiles id="sidebar-logo" img_class="h-11 w-auto" class="shrink-0" />
              </div>

              <.navlist heading="Workspace">
                <.navlink navigate={~p"/onboarding"}>
                  <.icon name="hero-arrow-trending-up" class="size-5" /> Onboarding
                </.navlink>
                <.navlink navigate={~p"/dashboard"}>
                  <.icon name="hero-chart-bar-square" class="size-5" /> Dashboard
                </.navlink>
                <.navlink navigate={~p"/agents"}>
                  <.icon name="hero-user-circle" class="size-5" /> Agents
                </.navlink>
                <.navlink navigate={~p"/integrations"}>
                  <.icon name="hero-wrench-screwdriver" class="size-5" /> Integrations
                </.navlink>
                <.navlink navigate={~p"/numbers"}>
                  <.icon name="hero-hashtag" class="size-5" /> Numbers
                </.navlink>
                <.navlink navigate={~p"/calls"}>
                  <.icon name="hero-phone" class="size-5" /> Calls
                </.navlink>
              </.navlist>

              <.navlist heading="Organization">
                <.navlink navigate={~p"/settings/members"}>
                  <.icon name="hero-user-group" class="size-5" /> Members
                </.navlink>
                <.navlink navigate={~p"/users/settings"}>
                  <.icon name="hero-cog-6-tooth" class="size-5" /> Settings
                </.navlink>
              </.navlist>

              <.navlist class="mt-auto!">
                <.navlink href={~p"/users/log-out"} method="delete">
                  <.icon name="hero-arrow-right-on-rectangle" class="size-5" /> Sign out
                </.navlink>
              </.navlist>
            </div>

            <div class="max-md:hidden flex flex-col border-t border-base p-4">
              <.dropdown class="w-56">
                <:toggle class="w-full">
                  <button class="cursor-default flex w-full items-center gap-3 rounded-base px-2 py-2.5">
                    <div class="flex min-w-0 items-center gap-3">
                      <div class="size-10 shrink-0 rounded-base overflow-hidden">
                        <img class="size-full" src={avatar_url} alt="" />
                      </div>

                      <div class="min-w-0 text-left">
                        <span class="block truncate text-sm font-medium text-foreground">
                          {avatar_text}
                        </span>
                        <span class="block truncate text-xs font-normal text-foreground-softer">
                          {tenant && tenant.name}
                        </span>
                      </div>
                    </div>

                    <.icon
                      name="hero-chevron-up"
                      class="size-3 text-foreground-softer group-hover:text-foreground ml-auto"
                    />
                  </button>
                </:toggle>

                <.dropdown_link navigate={~p"/users/settings"}>Profile</.dropdown_link>
                <.dropdown_link navigate={~p"/settings/members"}>Members</.dropdown_link>
                <.dropdown_link href={~p"/users/log-out"} method="delete">Sign Out</.dropdown_link>
              </.dropdown>
            </div>
          </div>
        </div>

        <header class="flex items-center px-4 md:hidden border-b border-base bg-base">
          <div class="py-2.5">
            <span class="relative">
              <button
                phx-click={Fluxon.open_dialog("mobile-sidebar-nav")}
                class="cursor-default relative flex min-w-0 items-center gap-3 rounded-base p-2"
              >
                <.icon name="hero-bars-3" class="size-6" />
              </button>
            </span>
          </div>
          <div class="min-w-0 flex-1">
            <nav class="flex flex-1 items-center gap-4 py-2.5">
              <div class="flex items-center gap-3 ml-auto">
                <.dropdown placement="bottom-end">
                  <:toggle class="w-full flex items-center">
                    <button class="cursor-default size-9 rounded-base overflow-hidden">
                      <img class="size-full" src={avatar_url} alt="" />
                    </button>
                  </:toggle>

                  <.dropdown_link navigate={~p"/users/settings"}>Profile</.dropdown_link>
                  <.dropdown_link navigate={~p"/settings/members"}>Members</.dropdown_link>
                  <.dropdown_link href={~p"/users/log-out"} method="delete">Sign Out</.dropdown_link>
                </.dropdown>
              </div>
            </nav>
          </div>
        </header>
        <main class="flex flex-1 flex-col md:min-w-0 md:p-2 md:pl-64">
          <div class="grow p-6 md:rounded-base md:bg-base md:p-10 md:border md:border-base">
            {render_slot(@inner_block)}
          </div>
        </main>
      </div>
    <% else %>
      <div class="min-h-svh">
        {render_slot(@inner_block)}
      </div>
    <% end %>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :class, :string, default: nil
  attr :img_class, :string, default: "h-12 w-auto"
  attr :alt, :string, default: "Swati AI"

  def logo_with_tiles(assigns) do
    pattern_id = "#{assigns.id}-pattern"
    fade_id = "#{assigns.id}-fade-gradient"
    mask_id = "#{assigns.id}-fade-mask"

    assigns =
      assigns
      |> assign(:pattern_id, pattern_id)
      |> assign(:fade_id, fade_id)
      |> assign(:mask_id, mask_id)

    ~H"""
    <div class={["relative inline-flex items-center justify-center overflow-visible", @class]}>
      <div class="absolute -inset-3 rounded-base overflow-hidden">
        <svg
          aria-hidden="true"
          class="absolute inset-0 size-full text-foreground/60"
          width="100%"
          height="100%"
          xmlns="http://www.w3.org/2000/svg"
        >
          <defs>
            <pattern
              id={@pattern_id}
              x="0"
              y="0"
              width="36"
              height="36"
              patternUnits="userSpaceOnUse"
            >
              <g fill="none" opacity="0.45">
                <path d="M36 18L0 18" stroke="currentColor"></path>
                <path d="M18 0V36" stroke="currentColor"></path>
              </g>
              <g opacity="0.18">
                <rect width="18" height="18" fill="currentColor"></rect>
                <rect x="18" y="18" width="18" height="18" fill="currentColor"></rect>
              </g>
            </pattern>

            <radialGradient id={@fade_id} cx="50%" cy="50%" r="50%" fx="50%" fy="50%">
              <stop offset="0%" stop-color="white" stop-opacity="1"></stop>
              <stop offset="60%" stop-color="white" stop-opacity="0.6"></stop>
              <stop offset="100%" stop-color="white" stop-opacity="0.1"></stop>
            </radialGradient>

            <mask id={@mask_id}>
              <rect width="100%" height="100%" fill={"url(##{@fade_id})"}></rect>
            </mask>
          </defs>

          <rect width="100%" height="100%" fill={"url(##{@pattern_id})"} mask={"url(##{@mask_id})"}>
          </rect>
        </svg>
      </div>

      <img src={~p"/images/swati_logo.png"} alt={@alt} class={["relative z-10", @img_class]} />
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
