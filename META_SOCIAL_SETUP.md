# Facebook & Instagram Integration Setup

Two separate Meta apps are required — one for **Facebook Messenger** (already have an App ID) and one for **Instagram API with Instagram Login**.

---

## Part 1 — Facebook Messenger (DMs + Comments)

Your `.env` already has:
```
FB_APP_ID=1516765799861812
FB_APP_SECRET=...
FB_VERIFY_TOKEN=hello123
```

### Steps to configure in the Meta Developer Portal

1. Go to [developers.facebook.com](https://developers.facebook.com) → **My Apps** → open app `1516765799861812`.

2. **App Domains & OAuth redirect URIs**
   - Left sidebar → **App Settings → Basic**
   - Add your Cloudflare tunnel hostname (e.g. `abc123.trycloudflare.com`) to **App Domains**
   - Save Changes

3. **Facebook Login product**
   - If "Facebook Login" isn't listed under **Add a Product**, add it.
   - Go to **Facebook Login → Settings**
   - Under **Valid OAuth Redirect URIs** add:
     ```
     https://<tunnel-host>/
     ```
     Replace `<tunnel-host>` with your actual Cloudflare tunnel hostname.
   - Enable **Client OAuth Login** and **Web OAuth Login**
   - Save Changes

4. **Messenger product — Webhook**
   - Add the **Messenger** product if not present.
   - Go to **Messenger → Settings → Webhooks**
   - Callback URL:
     ```
     https://<tunnel-host>/bot/webhook
     ```
   - Verify Token: `hello123`  (matches `FB_VERIFY_TOKEN` in your `.env`)
   - Subscribe to: `messages`, `messaging_postbacks`, `messaging_optins`, `message_deliveries`, `message_reads`, `message_echoes`

5. **Permissions** — Go to **App Review → Permissions and Features**, request:
   - `pages_manage_metadata`
   - `pages_messaging`
   - `pages_show_list`
   - `pages_read_engagement`
   - `instagram_basic`
   - `instagram_manage_messages`

   In development mode these are usable by admins/testers without formal review.

6. **Add yourself as a test user**
   - Left sidebar → **Roles → Test Users** or **Roles → Roles** — add your Facebook account as an Admin or Tester.

7. **Restart Rails and run the sync task:**
   ```bash
   bundle exec rails chatwoot:sync_env_configs
   bundle exec rails server
   ```

---

## Part 2 — Instagram (Direct Instagram Login)

This requires a **separate** Meta app configured with the "Instagram API with Instagram Login" product.

### Create the Instagram App

1. Go to [developers.facebook.com](https://developers.facebook.com) → **My Apps → Create App**
2. Choose **Other → Next → Business → Next**
3. Give it a name (e.g., "Durian Instagram") → Create
4. On the dashboard click **Add Product** → find **Instagram API with Instagram Login** → Set Up

### Configure the Instagram App

5. **App Settings → Basic**
   - Copy the **App ID** → put it in `.env` as `INSTAGRAM_APP_ID`
   - Copy the **App Secret** → put it in `.env` as `INSTAGRAM_APP_SECRET`
   - Add your Cloudflare tunnel hostname (e.g. `abc123.trycloudflare.com`) to **App Domains**

6. **Instagram API with Instagram Login → Settings**
   - Under **User Token Generator**, add your Instagram test account
   - Under **Redirect URIs** add:
     ```
     https://<tunnel-host>/instagram/callback
     ```
   - Save

7. **Webhook** (for receiving DMs and comments)
   - Go to **Instagram API with Instagram Login → Webhooks**
   - Callback URL:
     ```
     https://<tunnel-host>/webhooks/instagram
     ```
   - Verify Token: `hello123`  (matches `INSTAGRAM_VERIFY_TOKEN` and `IG_VERIFY_TOKEN`)
   - Subscribe to: `messages`, `messaging_seen`, `message_reactions`

8. **Permissions**
   - `instagram_business_basic`
   - `instagram_business_manage_messages`
   - `instagram_business_manage_comments`  ← for comments

9. **Update `.env`** with the new values:
   ```
   INSTAGRAM_APP_ID=<your new app id>
   INSTAGRAM_APP_SECRET=<your new app secret>
   INSTAGRAM_VERIFY_TOKEN=hello123
   ```

10. **Sync to DB and restart:**
    ```bash
    bundle exec rails chatwoot:sync_env_configs
    bundle exec rails server
    ```

---

## Using Cloudflare Tunnel for local development

Meta's Instagram Business API **only works over HTTPS** — plain `http://localhost` is rejected. Cloudflare Tunnel gives you a free, no-account-needed HTTPS URL in seconds.

### Install cloudflared (once)

```bash
# macOS
brew install cloudflared

# or download directly
# https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/
```

### Run the tunnel

```bash
# Terminal 1 — your Rails server
bundle exec rails server

# Terminal 2 — Cloudflare Tunnel
cloudflared tunnel --url http://localhost:3000
```

cloudflared prints a URL like:
```
https://abc123.trycloudflare.com
```

Use that hostname everywhere `<tunnel-host>` appears above.

### Update `.env` with the tunnel URL

```
FRONTEND_URL=https://abc123.trycloudflare.com
```

Then re-run the sync task and restart Rails:

```bash
bundle exec rails chatwoot:sync_env_configs
bundle exec rails server
```

> **Heads-up:** The free quick-tunnel URL changes every time you restart cloudflared. When it changes you need to update App Domains, OAuth redirect URIs, and webhook URLs in the Meta Developer Portal, and update `FRONTEND_URL` in `.env` again. For a stable URL, set up a [named tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/) with your own domain.

---

## Quick reference — which env var does what

| Variable | Used for |
|---|---|
| `FB_APP_ID` | Facebook Login JS SDK + Messenger integration |
| `FB_APP_SECRET` | Exchanging short-lived → long-lived Facebook tokens |
| `FB_VERIFY_TOKEN` | Meta verifying the Facebook Messenger webhook endpoint |
| `IG_VERIFY_TOKEN` | Meta verifying the Instagram webhook via the Facebook Page flow |
| `INSTAGRAM_APP_ID` | Instagram OAuth (enables the Instagram button in the UI) |
| `INSTAGRAM_APP_SECRET` | Instagram OAuth token exchange + JWT state signing |
| `INSTAGRAM_VERIFY_TOKEN` | Meta verifying the `/webhooks/instagram` endpoint |
