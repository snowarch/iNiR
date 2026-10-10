# Community Hub

Widgets, colour themes, iRiS themes and web apps made by people who use iNiR, installed with one click and removed just as cleanly. The catalogue lives in its own repository, [snowarch/inir-hub](https://github.com/snowarch/inir-hub), and anyone can add to it with a pull request.

## Open it

| Family | Where |
| --- | --- |
| Material | Settings › Hub |
| iRiS | Settings › More Settings › Community Hub |
| Waffle | Settings › Hub |

`inir hub open` opens it in whichever family you use, and `inir hub open <id>` opens one item's page.

Each card says where the item shows up in the family you're using, and what it can do beyond drawing itself. Get installs it; then Use, Apply or Remove do what they say.

## From a terminal

```bash
inir hub list                  # everything; ● installed, ↑ update waiting
inir hub list --installed
inir hub search clock
inir hub info countdown
inir hub install countdown
inir hub update all
inir hub remove countdown
inir hub sync                  # read the catalogue again now
```

These work with or without the shell running, and add `--json` for scripts. When the shell is running it hears about every change and updates its pages.

## What goes where

| Kind | Installs to | Shows up |
| --- | --- | --- |
| Widget | `~/.config/inir/widgets/<id>/` | Material desktop, the iRiS Island's Desktop page, Waffle's Widgets panel (each widget says which) |
| Colour theme | `~/.config/inir/themes/<id>.json` | Settings › Themes, beside your own saved themes |
| iRiS theme | `~/.config/inir/iris/themes/<id>.json` | iRiS Themes, beside the built-in ones |
| Web app | `~/.config/inir/plugins/<id>/` | A tab in Material's left sidebar |

The Hub keeps a record of what it installed in `~/.local/state/inir/hub/installed.json`. Remove only touches those; widgets and themes you made yourself are never changed, and an item whose id clashes with one of yours is shown as a conflict instead of installed over it.

Removing an item deletes its files. Its settings stay in your config, so installing it again brings it back as you had it.

In Waffle, cards from your widgets appear in the Widgets panel; Settings › Waffle Style › Show your widgets turns them off.

## Permissions

| The card says | The item |
| --- | --- |
| Runs commands on your computer | starts processes (`Process`, `sh -c`) |
| Talks to the internet | makes network requests |
| Reads or writes files outside its own folder | uses files elsewhere in your home |
| Injects scripts into the site it opens | (web apps) runs scripts inside the page |

Items reach the Hub by pull request and are read before they merge. CI checks that the code does nothing it doesn't declare, and every package is checked against its sha256 before it installs. Widgets run inside the shell with the same access as the shell, so read what you install, especially anything that runs commands.

## Sources

The official catalogue is always read. Add more under Sources at the bottom of the Hub page: the address of an `index.json`, or a local folder with one. They are saved in `hub.sources` in your config. When two sources list the same id, the first one wins.

`INIR_HUB_SOURCES` replaces every source for one command, which is how you try a hub you are building:

```bash
INIR_HUB_SOURCES=$PWD/dist inir hub install my-widget
```

The catalogue is cached in `~/.cache/inir/hub` and read again every few hours, or with `inir hub sync`. Offline, the Hub shows what it read last.

## Make something

The [contributing guide](https://github.com/snowarch/inir-hub/blob/main/CONTRIBUTING.md) covers every kind, with templates and examples to copy. For widgets, the [Widget SDK](https://github.com/snowarch/inir/blob/main/defaults/widgets/WIDGET-SDK.md) and the [iRiS SDK](https://github.com/snowarch/inir/blob/main/defaults/widgets/IRIS-SDK.md) are the reference.

## Scripting

The `hub` IPC target (`refresh`, `install`, `update`, `remove`, `use`, `openItem`, `status`, `changed`) is listed in the [IPC reference](IPC).
