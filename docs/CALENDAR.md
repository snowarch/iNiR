# Calendar Integration

iNiR can display events from external calendars (Google Calendar, Outlook, Nextcloud, Apple iCloud, or any CalDAV server) alongside your local events in the sidebar calendar.

No accounts, no OAuth, no tokens. You paste an ICS URL and events show up.

---

## How it works

Every calendar provider exposes a standard ICS/iCal URL for each calendar. iNiR fetches these URLs periodically (default: every 15 minutes), parses the events, and merges them with your local events. External events are read-only: you can see them but not edit or delete them from the shell.

Each calendar source gets its own color dot on the calendar grid, so you can tell at a glance which calendar an event belongs to.

---

## Setup

Open **Settings > Services > Calendar Sync** (Material ii) or **Waffle Settings > General > Calendar** (Waffle).

1. Enable **External calendar sync**
2. Click **Add**
3. Enter a name, paste the ICS URL, and pick a color
4. Done. Events appear immediately

You can add multiple calendars. Each one syncs independently.

---

## Getting ICS URLs

### Google Calendar

1. Go to [calendar.google.com](https://calendar.google.com)
2. Hover over the calendar you want in the left sidebar, click the three dots > **Settings and sharing**
3. Scroll down to **Integrate calendar**
4. Copy **Secret address in iCal format** (the URL ending in `.ics`)

> Each Google Calendar (Personal, Work, Birthdays, etc.) has its own ICS URL. Add them separately for individual colors.

### Outlook / Microsoft 365

1. Go to [outlook.live.com](https://outlook.live.com) (or your M365 account)
2. Settings (gear icon) > **View all Outlook settings**
3. **Calendar** > **Shared calendars**
4. Under **Publish a calendar**, select the calendar and click **Publish**
5. Copy the **ICS** link

### Apple iCloud

1. Open iCloud Calendar at [icloud.com/calendar](https://icloud.com/calendar)
2. Click the share icon next to a calendar
3. Check **Public Calendar**
4. Copy the `webcal://` URL
5. Change `webcal://` to `https://` before pasting into iNiR

### Nextcloud

1. In the Nextcloud Calendar app, click the three dots next to a calendar
2. Click **Copy subscription link**
3. Paste the URL

### Other CalDAV servers (Radicale, Baikal, etc.)

Most CalDAV servers expose an ICS endpoint per calendar. Check your server's documentation for the subscription URL.

---

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| External calendar sync | Off | Master toggle for fetching external calendars |
| Refresh interval | 15 min | How often to re-fetch (5 min to 2 hours) |
| Show upcoming events | On | Show upcoming events below the calendar grid |
| Upcoming days | 3 | How many days ahead to show in upcoming view |

---

## How events are displayed

### Material ii (sidebar right)

- **Calendar grid**: colored dots per source on days with events (up to 3 dots visible, then a `+` overflow indicator)
- **Click any day**: opens a day detail view with events grouped by Morning, Afternoon, Evening, and All Day
- **Events tab**: merged timeline of local + external events for the next 30 days, sorted by date

External events in the Events tab show:
- A cloud sync icon instead of a category icon
- The calendar source name as a colored badge
- Location or description if available
- No edit/delete buttons (read-only)

### Waffle (notification center)

- **Calendar grid**: colored dots on days with events (accent color for local, source color for external)
- **Click any day**: inline detail section with all events for that day
- **Upcoming section**: next 3 days of events below the grid (when no day is selected)

---

## Privacy

The ICS URL is stored in your local `config.json` and nowhere else. Fetches go directly from your machine to the calendar provider. There's no intermediary server.

The "secret" ICS URL from Google Calendar grants read-only access to that calendar. Anyone with the URL can see your events, so treat it like a password. If compromised, regenerate it from Google Calendar settings.

Event data is cached locally at `~/.local/state/quickshell/user/calendar-sync-cache.json` so events are available on restart without re-fetching.

---

## Troubleshooting

**Events not showing up after adding a source:**

Check for errors in the Settings UI. A red error icon appears next to sources that failed to fetch. Common causes:
- Invalid or expired ICS URL
- Network connectivity issues
- URL requires authentication (only public/secret ICS URLs work, not URLs behind login)

**Force refresh:**

Currently there's no manual refresh button in the UI. The service re-fetches when:
- A new source is added
- A source is re-enabled
- The refresh timer fires
- The shell restarts

For debugging:
```bash
QS_DEBUG=1 qs -c inir    # shows [CalendarSync] log lines
```

**Cache issues:**

Delete the cache file to force a clean re-fetch:
```bash
rm ~/.local/state/quickshell/user/calendar-sync-cache.json
inir restart
```
