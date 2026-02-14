export const WhatsAppEmbeddedSignup = {
  mounted() {
    this.appId = this.el.dataset.appId
    this.configId = this.el.dataset.configId
    this.apiVersion = this.el.dataset.apiVersion
    this.sdkReady = this.loadFacebookSDK()

    this.handleEvent("whatsapp_start_signup", async () => {
      await this.sdkReady
      this.launchEmbeddedSignup()
    })
  },

  loadFacebookSDK() {
    if (window.FB) {
      return Promise.resolve()
    }

    return new Promise((resolve, reject) => {
      window.fbAsyncInit = () => {
        if (!this.appId || !this.apiVersion) {
          reject(new Error("Missing Facebook SDK configuration"))
          return
        }

        window.FB.init({
          appId: this.appId,
          cookie: true,
          xfbml: true,
          version: this.apiVersion,
        })

        resolve()
      }

      const existing = document.querySelector("script[data-facebook-sdk]")
      if (existing) {
        existing.addEventListener("load", () => resolve())
        existing.addEventListener("error", () => reject())
        return
      }

      const script = document.createElement("script")
      script.src = "https://connect.facebook.net/en_US/sdk.js"
      script.async = true
      script.defer = true
      script.dataset.facebookSdk = "true"
      script.onload = () => resolve()
      script.onerror = () => reject()
      document.body.appendChild(script)
    })
  },

  launchEmbeddedSignup() {
    if (!window.FB || !this.configId) {
      this.pushEvent("whatsapp_auth_cancelled", {})
      return
    }

    window.FB.login(
      (response) => {
        const code = response?.authResponse?.code
        if (code) {
          this.pushEvent("whatsapp_auth_success", { code })
        } else {
          this.pushEvent("whatsapp_auth_cancelled", {})
        }
      },
      {
        config_id: this.configId,
        response_type: "code",
        override_default_response_type: true,
        extras: {
          feature: "whatsapp_embedded_signup",
          version: 2,
          sessionInfoVersion: 2,
        },
      },
    )
  },
}
