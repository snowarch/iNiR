# Community Hub

The Hub has widgets, colour themes, iRiS themes and web apps made by people who use iNiR. You install them with one click and remove them just as cleanly. The catalogue lives in [snowarch/inir-hub](https://github.com/snowarch/inir-hub), and anyone can add to it with a pull request.

The three families come from the Hub too. Setup installs them and `inir update` keeps them current, so this page is
about the extras.

## Open the Hub

- Material: **Settings › Hub**
- Waffle: **Waffle Settings › Hub**
- iRiS: **iRiS Settings › Community Hub**, in the footer under the list

## Find things

The search bar looks through names, summaries, tags and authors. Beside it:

- **The order**: Popular (downloads weighed by how long an item has been out, and its votes), Most downloaded, Top
  rated, Newest, Recently updated, A to Z.
- **List or grid**: rows show the most at once; the grid shows bigger pictures. The Hub remembers both.
- **The chips** under it narrow to one kind, to what you have installed, or to what has an update. Each says how many
  there are.

Every row shows how many people liked the item, how many downloaded it, and when it last changed. Votes are the
thumbs up and down on the item's discussion: **Reviews and votes** on its page takes you there, or from a terminal:

```sh
inir hub rate excalidraw up      # down, or clear to take your vote back
```

With `gh` logged in the vote goes straight in; without it, the discussion opens in your browser.

## Install and remove

Each row says where the item shows up in your family and which permissions it asks for. Press **Get** to install it. Then:

- **Add to desktop** (Material) and **Use** (iRiS) put a widget on your desktop.
- **Use** switches to a colour theme or an iRiS theme.
- **Update** appears when a newer version is out. **Update N** (N is how many are waiting) does every one, and so does `inir update`. The
  update check posts a notice when your items have new versions.
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

A shield on a row means the item asks for permissions; its page lists them, with every internet address its code
talks to under **Reaches**. **Runs commands on your computer** means it starts programs. **Talks to the internet** means it makes network requests. **Reads or writes files outside its own folder** means it uses files elsewhere in your home. **Injects scripts into the site it opens** applies to web apps.

Items are read before they are added to the catalogue, and every download is checked before it installs. Widgets run inside the shell, so check the permissions before you install one, especially anything that runs commands.

Every submission goes through `inir hub audit` before a person reviews it: code that reads keys, passwords or browser
cookies, asks for root, starts itself outside the shell, sends data to paste sites or webhooks, mines, listens to the
keyboard, hides what it does (encoded blobs, minified code, invisible characters) or talks to hosts it didn't declare
is refused, and code that reads as generated without care gets a quality score a maintainer has to sign off.

If an item turns out to be bad after it was published, the Hub pulls it: it can't be installed any more, and if you
have it, its page says why and **Remove** takes it off. **Report** on any item's page tells the maintainers.

## Sources

The official catalogue is always read. To add another, use **Sources** at the bottom of the Hub page and paste the address of an `index.json`, or a folder that has one. If two sources list the same item, the first one wins.

The catalogue refreshes about every six hours. Offline, the Hub shows the last list it got.

## Make something

The [contributing guide](https://github.com/snowarch/inir-hub/blob/main/CONTRIBUTING.md) has templates for every kind, and `inir hub submit` sends what you made as a pull request. For widgets, the [widget guide](https://github.com/snowarch/inir-hub/blob/main/guides/widgets.md) and the [iRiS widget guide](https://github.com/snowarch/inir-hub/blob/main/guides/iris-widgets.md) are the reference.
