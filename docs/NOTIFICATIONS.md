# Notifications

How notifications work in iNiR, from arrival to display to history.

## How it works

iNiR implements the freedesktop notification spec via Quickshell's notification module. Apps send notifications over D-Bus, iNiR receives them, shows popups, and stores history.

When iNiR starts, it tells the session it's the notification daemon. If another notification daemon is running (mako, dunst, etc.), iNiR's ConflictKiller handles the conflict on startup.

## Popups

New notifications appear as popup toasts. Each popup stays visible for 7 seconds by default, then moves to history.

Popup behavior depends on context:

- **Normal**: popup appears, auto-dismisses after timeout
- **Sidebar open**: popups are suppressed (you're already looking at notifications)
- **GameMode active**: popups suppressed if `suppressNotifications` is enabled
- **Critical urgency**: popup stays until manually dismissed

### Rate limiting

Max 20 notifications per second. Spam from misbehaving apps gets throttled instead of flooding your screen.

## Do Not Disturb

Toggle DND from:
- Right sidebar toggle (ii)
- Action center toggle (waffle)
- IPC: `inir notifications toggleSilent`

When DND is on, new notifications still arrive and get stored in history. They just don't show popups.

## Quiet hours

A daily window that suppresses popups without you remembering to toggle DND. Enable it in Settings › Interface › Notifications, or in the config:

```json
"notifications": {
  "quietHours": {
    "enable": true,
    "start": "22:00",
    "end": "08:00"
  }
}
```

Times are 24-hour `HH:MM`. A window whose `end` is earlier than its `start` wraps past midnight, so the example above runs from 10 PM to 8 AM. An unparseable time disables the window rather than guessing.

Like DND, quiet hours only holds back popups — notifications still reach the history.

## History

Notifications persist across shell restarts. History is stored at:

```
~/.local/state/quickshell/user/notifications.json
```

View history in the right sidebar (ii) or notification center (waffle). Notifications are grouped by app name for easier scanning.

Once more than three notifications are stored, a search field appears above the list. It matches on app name, summary and body, and hides groups with no match.

### Grouping

Notifications from the same app collapse into groups. Each group shows:
- App name and icon
- Number of notifications
- Whether any are critical
- Most recent notification time

Expand a group to see individual notifications.

## Actions

If a notification includes action buttons (like "Reply" or "Open"), they appear on the notification. Clicking an action triggers the corresponding D-Bus callback to the source app.

## Display

### Material ii

Popups appear at the top-right. The right sidebar has a full notification center with grouped history, dismiss-all, and DND toggle.

### Waffle

Popups appear at the bottom-right (Windows 11 style). The notification center (`wNotificationCenter`) is a panel that slides from the right edge with grouped notification history and an integrated calendar.

## IPC

```bash
inir notifications clearAll          # Clear all notifications
inir notifications toggleSilent      # Toggle DND
```

## Troubleshooting

**No notifications showing up**: check if another notification daemon is running (`pidof mako dunst`). iNiR's ConflictKiller should handle this, but if it doesn't, kill the other daemon manually.

**Notifications from specific apps missing**: some apps send notifications to specific categories or with transient hints. Check `inir logs` for notification-related messages.
