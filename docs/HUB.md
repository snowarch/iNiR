# Community Hub

The Hub has widgets, colour themes, iRiS themes and web apps made by people who use iNiR. You install them with one click and remove them just as cleanly. The catalogue lives in [snowarch/inir-hub](https://github.com/snowarch/inir-hub), and anyone can add to it with a pull request.

## Open the Hub

- Material: **Settings › Hub**
- Waffle: **Waffle Settings › Hub**
- iRiS: **iRiS Settings › Community Hub**, in the footer under the list

## Install and remove

Each card says where the item shows up in your family and which permissions it asks for. Press **Get** to install it. Then:

- **Add to desktop** (Material) and **Use** (iRiS) put a widget on your desktop.
- **Apply** switches to a colour theme or an iRiS theme.
- **Update** appears when a newer version is out. **Update all** does every one.
- **Remove** is on the item's page. It deletes the item's files and nothing else.

If a folder you made already has the item's name, the card says **Name taken**, and nothing is installed over your folder.

| Kind | Shows up |
| --- | --- |
| Widgets | Material's desktop, the iRiS Island, Waffle's Widgets panel |
| Colour themes | Settings › Themes, beside your own |
| iRiS themes | The iRiS theme list, beside the built-in ones |
| Web apps | A tab in Material's left sidebar |

In Waffle, **Waffle Settings › Waffle Style › Show your widgets** hides the hub widgets from the Widgets panel.

## Permissions

Each card lists what the item does. **Runs commands on your computer** means it starts programs. **Talks to the internet** means it makes network requests. **Reads or writes files outside its own folder** means it uses files elsewhere in your home. **Injects scripts into the site it opens** applies to web apps.

Items are read before they are added to the catalogue, and every download is checked before it installs. Widgets run inside the shell, so check the permissions before you install one, especially anything that runs commands.

## Sources

The official catalogue is always read. To add another, use **Sources** at the bottom of the Hub page and paste the address of an `index.json`, or a folder that has one. If two sources list the same item, the first one wins.

The catalogue refreshes about every six hours. Offline, the Hub shows the last list it got.

## Make something

The [contributing guide](https://github.com/snowarch/inir-hub/blob/main/CONTRIBUTING.md) has templates for every kind. For widgets, the [Widget SDK](https://github.com/snowarch/inir/blob/main/defaults/widgets/WIDGET-SDK.md) and the [iRiS SDK](https://github.com/snowarch/inir/blob/main/defaults/widgets/IRIS-SDK.md) are the reference.
