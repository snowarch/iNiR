<p align="center">
  <img src="../images/iris-2.32-principal.webp" alt="iNiR iRiS desktop" width="900">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>Niri के लिए एक पूरा डेस्कटॉप शेल, Quickshell पर बना</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.32.0-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-green?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/wiki/INSTALL">इंस्टॉल</a> &bull;
  <a href="https://github.com/snowarch/inir/wiki/KEYBINDS">शॉर्टकट</a> &bull;
  <a href="https://github.com/snowarch/inir/wiki/IPC">IPC संदर्भ</a> &bull;
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a> &bull;
  <a href="../../CONTRIBUTING.md">योगदान</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

---

> **इस अनुवाद के बारे में:** कुछ साफ़ न हो तो [अंग्रेज़ी संस्करण](../../README.md) को ही सही मानें।

---

<details>
<summary><b>🤔 नए हैं? अगर पता नहीं कि यह सब क्या है, तो क्लिक करें</b></summary>

### यह क्या है?

iNiR आपका पूरा डेस्कटॉप है। ऊपर का बार, डॉक, नोटिफ़िकेशन, सेटिंग्स, वॉलपेपर, सब कुछ। यह कोई थीम नहीं है, न ही चिपकाने वाली dotfiles। यह Linux पर चलने वाला एक पूरा शेल है।

### इसे चलाने के लिए क्या चाहिए?

एक कंपोज़िटर। यही आपकी विंडो संभालता है और स्क्रीन पर पिक्सल बनाता है। iNiR [Niri](https://github.com/YaLTeR/niri) (एक टाइलिंग Wayland कंपोज़िटर) के लिए बना है। उस समय का कुछ पुराना Hyprland कोड बचा है जब यह end-4 की dots का फ़ोर्क था, लेकिन मैं असल में Niri ही इस्तेमाल और टेस्ट करता हूँ।

शेल [Quickshell](https://quickshell.outfoxxed.me/) पर चलता है, जो QML (Qt की UI भाषा) में शेल बनाने का फ़्रेमवर्क है। इस्तेमाल करने के लिए यह सब जानना ज़रूरी नहीं: सब कुछ GUI या एक JSON फ़ाइल से सेट होता है।

### सब कैसे जुड़ता है

```
your apps
   ↓
iNiR (shell: bar, sidebars, dock, notifications, settings...)
   ↓
Quickshell (runs QML shells)
   ↓
Niri (compositor: windows, rendering)
   ↓
Wayland → GPU
```

### क्या यह स्थिर है?

यह एक निजी प्रोजेक्ट है जो हाथ से निकल गया। मैं इसे रोज़ इस्तेमाल करता हूँ, Discord पर बहुत लोग भी करते हैं। लेकिन कभी-कभी चीज़ें टूटती हैं, कोड कुछ जगह बिखरा हुआ है, और मैं चलते-चलते सीख रहा हूँ।

अगर कुछ काम न करे तो `inir doctor` ज़्यादातर चीज़ें ठीक कर देता है। फिर भी न हो तो Discord सक्रिय है। बस चमकाए हुए सॉफ़्टवेयर की उम्मीद न करें: यह एक इंसान का rice है जो दूसरों को भी पसंद आ गया।

### यह क्यों है?

मैं चाहता था कि मेरा डेस्कटॉप एक ख़ास तरह दिखे और काम करे, और कोई चीज़ ठीक वैसा नहीं करती थी। शुरुआत end-4 की Hyprland dots से हुई, और यह Niri के लिए कहीं ज़्यादा फ़ीचर वाला पूरा नया रूप बन गया।

### शब्द जो आपको दिखेंगे

- **शेल**: UI की परत (बार, पैनल, ओवरले)
- **कंपोज़िटर**: विंडो संभालता है, स्क्रीन पर बनाता है (Niri, Hyprland, Sway...)
- **Wayland**: Linux का डिस्प्ले प्रोटोकॉल (नया वाला, X11 की जगह)
- **QML**: Qt की डिक्लेरेटिव UI भाषा, जिसमें iNiR लिखा है
- **Material You**: Google का रंग सिस्टम जो तस्वीर से पैलेट बनाता है (ऑटो-थीम इसी से होती है)
- **ii / waffle / iRiS**: तीन पैनल फ़ैमिली। ii = Material Design जैसा, waffle = Windows 11 जैसा, iRiS = एक Island जो वही बन जाती है जो आप खोलते हैं। `Super+Shift+W` इनके बीच बदलता है

</details>

---

## स्क्रीनशॉट

<details open>
<summary><b>iRiS</b>: Island, Customize, मेन्यू बार, कार्ड और Dock</summary>

<p align="center">
  <img src="../images/iris-2.31-desktop.webp" alt="iRiS desktop layout" width="49%">
  <img src="../images/iris-2.31-card.webp" alt="iRiS card surface" width="49%">
</p>

<p align="center">
  <img src="../images/iris-2.31-dock.webp" alt="iRiS Dock and edge layout" width="99%">
</p>

</details>

<details open>
<summary><b>Material ii</b>: तैरता बार, साइडबार, Material Design का रूप</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b>: नीचे टास्कबार, एक्शन सेंटर, Windows 11 जैसा</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

> [!WARNING]
> कमज़ोर मशीनों के लिए नहीं है।
> फिर भी इसे काफ़ी हल्का किया जा सकता है: इफ़ेक्ट बंद करें, पैनल हटाएँ, डिज़ाइन सादा करें। सेटिंग्स से या `config.json` से, जैसा आपको ठीक लगे।

## फ़ीचर

**तीन पैनल फ़ैमिली**, `Super+Shift+W` से तुरंत बदलें:
- **Material ii**: तैरता बार, साइडबार, डॉक और 9 ग्लोबल स्टाइल (Material, Cards, Aurora, iNiR, Angel, Regalia, ZZZ, Cookie Shapes, Editorial)
- **Waffle**: Windows 11 जैसा टास्कबार, स्टार्ट मेन्यू, एक्शन सेंटर और नोटिफ़िकेशन सेंटर
- **iRiS**: फ़्लैगशिप फ़ैमिली। स्क्रीन के किसी भी किनारे पर एक Island जो पेज, कार्ड और पैनल में खुलती है, साथ ले जाने लायक पीस, किसी भी किनारे पर Dock, ग्लास, सब कुछ नए सिरे से बनाने वाली Themes, लाइट, इंक और डार्क, और सीधे शेल पर Customize

**ऑटोमैटिक थीम**। वॉलपेपर चुनें और सब कुछ उसके हिसाब से ढल जाता है:
- Material You से शेल के रंग, GTK3/4, Qt, टर्मिनल, Firefox, Discord, SDDM तक
- 10 थीम लक्ष्य: टर्मिनल, एडिटर, ब्राउज़र, Spicetify, Steam, Cava और भी
- थीम प्रीसेट: Regalia / Regalia Ivory, Gruvbox, Catppuccin, Rosé Pine और आपके अपने

**Niri के लिए बना।** Hyprland कोड फ़ोर्क से बचा है, पर टेस्ट नहीं होता।

**Kira**, मैस्कॉट, अगर आप चाहें तो आपके डेस्कटॉप पर रहती है। डिफ़ॉल्ट रूप से बंद, आर्ट पैक अलग से डाउनलोड होता है।

<details>
<summary><b>सभी फ़ीचर की सूची</b></summary>

### iRiS

- **Island**: स्क्रीन के किनारे पर एक आकार जो बताता है "क्या चल रहा है" और वही पेज, कार्ड या पैनल बन जाता है जो आपने खोला, फिर वापस सिमट जाता है। ऊपर, नीचे, बाएँ या दाएँ (`inir iris edge <side>`, या खींचकर वहाँ रख दें)। साइड पर यह खड़ी हो जाती है, घड़ी ऊपर-नीचे और बबल उसके ऊपर व नीचे
- **मेन्यू बार**: एक पतली पट्टी जिसमें आपके वर्कस्पेस, विंडो और पीस हैं, और Island उससे नॉच की तरह लटकती है (`inir iris layout menubar`)
- **पूरी चौड़ाई वाला बार मोड**, शुरुआत, बीच और अंत के ज़ोन के साथ, Island, वर्कस्पेस, फ़ोकस वाली विंडो, समय या किसी भी पीस के लिए (`inir iris zone start|center|end kinds+joined+with+plus`)
- **पीस**: मौसम, आवाज़, माइक, ट्रे, नोटिफ़िकेशन, टूल, मीडिया, VPN, एक विज़ुअलाइज़र, एनीमे (Airing और Continue) और आपके अपने ऐप, बबल के रूप में जिन्हें आप Island पर, स्क्रीन की रूपरेखा पर या डेस्कटॉप पर कहीं भी रख सकते हैं
- **पीस जिससे छूते हैं उसी से जुड़ जाते हैं**: किसी को Dock या Island के किनारे पर रखें, तो वह ऊपर तैरने के बजाय उसी का हिस्सा बन जाता है
- **Dock** किसी भी किनारे पर (`inir iris dockEdge <side|auto>`); auto में यह Island के सामने बैठता है, और एक को दूसरे के किनारे पर भेजें तो दोनों जगह बदल लेते हैं
- **ग्लास** जो हर सतह के नीचे वॉलपेपर को धुंधला करता है और चमकीले या भीड़ वाले वॉलपेपर पर भी टेक्स्ट पढ़ने लायक रखता है। कंपोज़िटर ब्लर भी है, पर अभी बन रहा है, तो अभी उसे मत आँकिए
- **Themes**: 20 चुने हुए रीडिज़ाइन (Liquid Glass, Frost, Obsidian, Terminal, Neo Tokyo, Twilight, Lume, Sakura, Unit-01 और भी) और आपके अपने, शेयर करने लायक JSON फ़ाइलों में (`inir iris theme`)
- **लाइट, इंक और डार्क**, हर एक का अपना टोन और धुंधलापन, और रंग थीम (Catppuccin, Nord, Rosé Pine, Tokyo Night…) जो आपके ऐप भी पहनते हैं (`inir iris palette`)
- **आकार**: Island और Dock के लिए कैप्सूल, गोल, स्क्विर्कल या चौकोर
- **शेल पर ही Customize**: Island, Dock या किसी बबल को टैप करें और उसके विकल्प वहीं से निकलते हैं, Island के नीचे Themes, Look, Pieces और अनडू के साथ (`inir iris edit`)। चाहें तो Studio सब कुछ स्क्रीन के बगल में एक पैनल में रखता है
- **कंट्रोल सेंटर जिसे आप खुद सजाते हैं**: हर साझा क्विक टॉगल, प्लेयर और हर स्लाइडर ऐसे सेल हैं जिन्हें आप खींचते हैं, कोने से बड़ा-छोटा करते हैं और बगल की लाइब्रेरी से जोड़ते हैं, छह शुरुआती लेआउट के साथ; राइट-क्लिक से कंट्रोल खुल जाता है (`inir iris control edit`)
- **लॉक स्क्रीन जिसका आप रिहर्सल करते हैं**: असली लॉक एडिट मोड में खुलता है और कुछ अनलॉक नहीं करना पड़ता; घड़ी, प्लेयर और साइन-इन फ़ील्ड को हिलाएँ, और पीछे क्या चले यह चुनें, वीडियो भी (`inir iris lock edit`)

### थीम और रूप

- **9 ग्लोबल स्टाइल**: Material (ठोस), Cards, Aurora (ग्लास ब्लर), iNiR (TUI से प्रेरित), Angel (नियो-ब्रूटलिज़्म), Regalia (काला ढाँचा, गर्म हाथीदाँत रंग की स्याही, संयमित शैंपेन रंग के हिस्से), ZZZ (पोस्टर प्लेट), Cookie Shapes (एनिमेटेड आकार), Editorial (काग़ज़ और स्याही वाली टाइपोग्राफ़ी)
- **वॉलपेपर से डायनेमिक रंग**, Material You के ज़रिए पूरे सिस्टम में
- **10 टर्मिनल और TUI टूल की ऑटो-थीम**: foot, kitty, alacritty, ghostty, wezterm, starship, fuzzel, btop, lazygit, yazi
- **ऐप थीम**: GTK3/4, Qt (plasma-integration और darkly से), Firefox, Discord/Vesktop (System24), Zed, Spicetify, Steam, SDDM
- **थीम प्रीसेट**: Gruvbox, Catppuccin, Rosé Pine और भी, या अपना बनाएँ
- **वीडियो वॉलपेपर**: mp4/webm/gif, ब्लर वैकल्पिक, या परफ़ॉर्मेंस के लिए पहला फ़्रेम रुका हुआ
- **डेस्कटॉप विजेट**: सबके लिए एक डिज़ाइन (iRiS, Material, iNstrument या Readout), iOS जैसे घूमने वाले स्टैक, और नीचे के वॉलपेपर के साथ बदलने वाली स्याही

### बार

- **6 बार स्टाइल**: classic, islands, scenic, frame, Material 3 कैप्सूल और pill
- **Pill बार**: बीच का आकार बदलने वाला द्वीप जो होवर पर वर्कस्पेस, लॉन्चर, मिक्सर, मीडिया, कैलेंडर और स्क्रीन रिकॉर्डर खोलता है
- **मॉड्यूलर लेआउट**, सेटिंग्स में ड्रैग एडिटर के साथ, कोई भी मॉड्यूल कहीं भी
- **वर्टिकल बार**, उनके लिए जो स्क्रीन का किनारा वापस चाहते हैं

### साइडबार और विजेट (Material ii)

बायाँ साइडबार (ऐप ड्रॉअर):
- **AI चैट**: Ollama, LM Studio, OpenRouter, Gemini, Groq, Mistral, Cerebras, Anthropic, OpenAI और OpenCode के लाइव मॉडल कैटलॉग
- **YT Music**: बिना कुकी का InnerTube प्लेयर, खोज, कतार, रेडियो और सिंक्ड लिरिक्स के साथ
- **Wallhaven ब्राउज़र**: वॉलपेपर सीधे खोजें और लगाएँ
- **एनीमे ट्रैकर**: AniList इंटीग्रेशन और शेड्यूल व्यू
- **अनुवादक**: Gemini या translate-shell से
- **खींचे जा सकने वाले विजेट**: क्रिप्टो, मीडिया प्लेयर, क्विक नोट्स, स्टेटस रिंग, साप्ताहिक कैलेंडर

दायाँ साइडबार:
- **कैलेंडर**, इवेंट के साथ
- **नोटिफ़िकेशन सेंटर**
- **क्विक टॉगल**: WiFi, Bluetooth, नाइट लाइट, परेशान न करें, पावर प्रोफ़ाइल, WARP VPN, EasyEffects
- **वॉल्यूम मिक्सर**, हर ऐप के लिए
- **Bluetooth और WiFi** डिवाइस प्रबंधन
- **पोमोडोरो टाइमर**, **टू-डू सूची**, **कैलकुलेटर**, **नोटपैड**
- **सिस्टम मॉनिटर**: CPU, RAM, तापमान

### टूल

- **वर्कस्पेस ओवरव्यू**: Niri के स्क्रॉलिंग मॉडल के हिसाब से, ऐप खोज और कैलकुलेटर के साथ
- **डैशबोर्ड**: तीन कॉलम वाला सेट करने लायक ओवरले, एजेंडा, नोटिफ़िकेशन, टू-डू, नोट्स, मीडिया और मौसम के साथ
- **किनारे की वर्कस्पेस पट्टी**: होवर पर आने वाली रेल, लाइव प्रीव्यू और खींचकर क्रम बदलने के साथ
- **विंडो स्विचर**: सभी वर्कस्पेस में एनिमेटेड Alt-Tab, वैकल्पिक, क्योंकि अब Niri का अपना है
- **क्लिपबोर्ड मैनेजर**: खोज और तस्वीर प्रीव्यू वाला इतिहास
- **क्षेत्र टूल**: स्क्रीनशॉट, स्क्रीन रिकॉर्डिंग, OCR, रिवर्स इमेज सर्च
- **चीटशीट**: आपके Niri कॉन्फ़िग से लिए गए शॉर्टकट
- **मीडिया कंट्रोल**: कई लेआउट वाला पूरा MPRIS प्लेयर
- **OSD**: वॉल्यूम, ब्राइटनेस और मीडिया
- **गाना पहचानना**: SongRec से Shazam जैसी पहचान
- **आवाज़ से लिखना**: इंस्टॉल हो तो लोकल whisper.cpp, वरना जुड़ा हुआ Groq, Gemini या OpenAI

### सिस्टम

- **GUI सेटिंग्स**: फ़ाइलें छुए बिना सब कुछ सेट करें
- **GameMode**: फ़ुलस्क्रीन ऐप में इफ़ेक्ट अपने-आप बंद
- **ऑटो-अपडेट**: `inir update`, रोलबैक, माइग्रेशन और आपके बदलाव सुरक्षित रखने के साथ
- **लॉक स्क्रीन** और **सेशन स्क्रीन** (लॉगआउट/रीबूट/शटडाउन/सस्पेंड)
- **Polkit एजेंट**, **ऑन-स्क्रीन कीबोर्ड**, niri की अपनी स्टार्टअप फ़ाइल पर आधारित **ऑटोस्टार्ट मैनेजर**
- **Kira**: पिक्सल-आर्ट बिल्ली-लड़की जो स्क्रीन के किनारों पर घूमती है, आपके काम पर प्रतिक्रिया देती है और जिसका एक केओस मोड है। वैकल्पिक, लगभग 32 MiB का अलग आर्ट पैक `./setup` › Extras में
- **18 भाषाएँ**, अपने-आप पहचान के साथ, इंडोनेशियाई (`id_ID`) और ग्रीनलैंडिक (`kl_GL`) समेत
- **नाइट लाइट**: तय समय पर या हाथ से
- **मौसम**: Open-Meteo, GPS, हाथ से दिए निर्देशांक या शहर के नाम से
- **बैटरी प्रबंधन**: सेट करने लायक सीमाएँ, बहुत कम बैटरी पर अपने-आप सस्पेंड
- **इवेंट की आवाज़ें**, मुख्य वॉल्यूम और हर इवेंट की अपनी ऑडियो फ़ाइल के साथ
- **अपडेट जाँच**: नया वर्ज़न आने पर बताता है

</details>

---

## जल्दी शुरू करें

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # interactive, asks before each step
./setup install -y    # automatic, no questions asked
```

इंस्टॉलर डिपेंडेंसी, सिस्टम कॉन्फ़िग और थीम संभालता है। इंस्टॉल के बाद शेल शुरू करने के लिए `inir run` चलाएँ, या लॉग आउट करके फिर लॉग इन करें।

```bash
inir run                        # launch the shell
inir settings                   # open settings GUI
inir logs                       # check runtime logs
inir doctor                     # auto-diagnose and fix
inir update                     # pull + migrate + restart
```

अगर `./setup install` आपको नहीं चाहिए, तो दूसरे तरीके:

```bash
./setup                 # TUI menu, pick what you want
sudo make install       # system-wide instead of your home
./setup rollback        # undo the last update
```

**डिस्ट्रो:** Arch मुख्य लक्ष्य है। Fedora और Debian/Ubuntu के लिए भी अपने-आप डिपेंडेंसी इंस्टॉल होती है, जो पहले डिस्ट्रो की रिपॉज़िटरी इस्तेमाल करती है; बाकी डिस्ट्रो [पैकेज सूची](https://github.com/snowarch/inir/wiki/PACKAGES) की सामान्य गाइड देखें। iNiR को Qt 6.9 या नया चाहिए: Ubuntu 25.10, Fedora 43 और Debian testing या उसके बाद।

---

## शॉर्टकट

| कुंजी | काम |
|-----|--------|
| <kbd>Super</kbd> + <kbd>Space</kbd> | ओवरव्यू: ऐप खोजें, वर्कस्पेस में जाएँ |
| <kbd>Super</kbd> + <kbd>V</kbd> | क्लिपबोर्ड इतिहास |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | किसी हिस्से का स्क्रीनशॉट |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>X</kbd> | किसी हिस्से का OCR |
| <kbd>Super</kbd> + <kbd>,</kbd> | सेटिंग्स |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | पैनल फ़ैमिली बदलें |
| <kbd>Super</kbd> + <kbd>/</kbd> | चीटशीट, अगर बाकी भूल जाएँ |

पूरी सूची: [शॉर्टकट](https://github.com/snowarch/inir/wiki/KEYBINDS)

---

## वॉलपेपर

15 वॉलपेपर साथ आते हैं। और चाहिए तो [iNiR-Walls](https://github.com/snowarch/iNiR-Walls) देखें, एक चुना हुआ संग्रह जो Material You के साथ अच्छा चलता है।

---

## दस्तावेज़

उपयोगकर्ताओं के लिए सब कुछ [Wiki](https://github.com/snowarch/inir/wiki) (अंग्रेज़ी में) पर है।

| पेज | क्या है |
|---|---|
| [Install](https://github.com/snowarch/inir/wiki/INSTALL) | चालू करना |
| [Setup](https://github.com/snowarch/inir/wiki/SETUP) | अपडेट, माइग्रेशन, रोलबैक |
| [Keybinds](https://github.com/snowarch/inir/wiki/KEYBINDS) | हर शॉर्टकट |
| [IPC](https://github.com/snowarch/inir/wiki/IPC) | शॉर्टकट और स्क्रिप्ट के लिए कमांड |
| [Packages](https://github.com/snowarch/inir/wiki/PACKAGES) | हर डिपेंडेंसी और वह क्यों है |
| [Limitations](https://github.com/snowarch/inir/wiki/LIMITATIONS) | जानी-पहचानी खामियाँ और उनके उपाय |
| [Architecture](../../ARCHITECTURE.md) | कोड कैसे बना है |

---

## समस्या समाधान

```bash
inir logs                       # check recent runtime logs
inir restart                    # restart the active runtime
inir repair                     # doctor + restart + filtered log check
./setup doctor                  # auto-diagnose and fix common problems
./setup rollback                # undo the last update
```

issue खोलने से पहले [Limitations](https://github.com/snowarch/inir/wiki/LIMITATIONS) देखें। किसी से सीधे पूछना हो तो Discord पर जल्दी जवाब मिलता है।

---

## योगदान

डेवलपमेंट सेटअप, कोड के तरीके और पुल रिक्वेस्ट भेजने के लिए [CONTRIBUTING.md](../../CONTRIBUTING.md) देखें।

---

## श्रेय

- [**end-4**](https://github.com/end-4/dots-hyprland): illogical-impulse, वे Hyprland dots जिनसे iNiR निकला
- [**pctrade/end4-pC**](https://github.com/pctrade/end4-pC): एक फ़ोर्क जिसमें कभी-कभी सच में अच्छा आइडिया होता है
- [**Gakuseei**](https://github.com/Gakuseei): [Ricelin](https://github.com/Gakuseei/Ricelin), जहाँ से pill बार और washi व flame वाला रूप आया
- [**Quickshell**](https://quickshell.outfoxxed.me/): वह फ़्रेमवर्क जिस पर यह चलता है
- [**Niri**](https://github.com/YaLTeR/niri): वह कंपोज़िटर जिसके लिए यह बना है

GPL-3.0, end-4 की dots की तरह। Copyright (C) 2025-2026 snowarch.

---

<p align="center">
  <img src="https://raw.githubusercontent.com/snowarch/inir-mascot/main/inir-mascot-hero-banner.png" alt="iNiR mascot leaning on the iNiR logotype" width="720">
</p>

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">योगदानकर्ता</a> &bull;
  <a href="../../CHANGELOG.md">Changelog</a> &bull;
  <a href="../../LICENSE">GPL-3.0 लाइसेंस</a>
</p>
