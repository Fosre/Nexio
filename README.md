# Nexio

Flutter starter for an Android messenger interface with phone OTP authentication and a built-in Nexio sticker picker.

## Included
- Phone number sign-in / registration through Supabase SMS OTP
- OTP verification screen
- Chat list and chat screen
- Built-in sticker/emoji picker
- Contacts, channels, calls and settings tabs
- Light and dark themes
- GitHub Actions APK build

## Important: real SMS requires backend setup
The app does not send SMS by itself. To receive a real code on the SIM:
1. Create a Supabase project.
2. In Supabase Authentication, enable Phone provider.
3. Configure an SMS provider and its credentials in Supabase. SMS delivery may cost money; free quotas and supported countries depend on the provider.
4. In GitHub repository Settings -> Secrets and variables -> Actions, add:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
5. Run the `Build Nexio APK` workflow.

Do not put service-role keys or SMS-provider secrets in the app. Only the Supabase project URL and anon/public key belong in the client build.

## Current limitations
This is an app foundation, not yet a complete production messenger. The chat UI and sticker picker are local demo interactions. Messages do not reach other users yet; profiles, database tables, realtime delivery, media storage, push notifications, group chats and abuse protections still need backend implementation.
