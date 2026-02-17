pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

Item {
    id: root
    implicitHeight: card.implicitHeight + Appearance.sizes.elevationMargin

    property var cryptoData: ({})
    property var sparklineData: ({})
    property bool loading: false
    property bool error: false
    property bool _cacheLoaded: false

    readonly property var coins: Config.options?.sidebar?.widgets?.crypto_settings?.coins ?? []
    readonly property int refreshInterval: (Config.options?.sidebar?.widgets?.crypto_settings?.refreshInterval ?? 60) * 1000
    readonly property string cachePath: FileUtils.trimFileProtocol(`${Directories.state}/user/crypto_cache.json`)

    // --- File-based cache ---
    FileView {
        id: cacheFile
        path: root.cachePath
        watchChanges: false

        onLoaded: {
            try {
                const cached = JSON.parse(cacheFile.text())
                if (cached.cryptoData && Object.keys(cached.cryptoData).length > 0) {
                    root.cryptoData = cached.cryptoData
                }
                if (cached.sparklineData && Object.keys(cached.sparklineData).length > 0) {
                    root.sparklineData = cached.sparklineData
                }
            } catch (e) {
                // Corrupted cache, ignore
            }
            root._cacheLoaded = true
        }

        onLoadFailed: (error) => {
            // No cache yet, that's fine
            root._cacheLoaded = true
        }
    }

    function saveCache() {
        try {
            cacheFile.setText(JSON.stringify({
                cryptoData: root.cryptoData,
                sparklineData: root.sparklineData,
                timestamp: Date.now()
            }))
        } catch (e) {
            // Non-critical, ignore write failures
        }
    }

    Timer {
        id: fetchTimer
        interval: root.refreshInterval
        running: root.coins.length > 0 && Config.ready
        repeat: true
        onTriggered: root.fetchPrices()
    }

    // Fetch only after cache has been attempted, and only if data is stale or missing
    Component.onCompleted: {
        // cacheFile.onLoaded / onLoadFailed will set _cacheLoaded
    }

    onCoinsChanged: {
        if (root._cacheLoaded && root.coins.length > 0) {
            // Check if we have data for all configured coins
            const hasMissing = root.coins.some(c => !(c in root.cryptoData))
            if (hasMissing) {
                Qt.callLater(() => root.fetchPrices())
            }
        }
    }

    on_CacheLoadedChanged: {
        if (root._cacheLoaded && root.coins.length > 0) {
            // If cache had no data or is stale (>5 min), fetch fresh
            const hasData = Object.keys(root.cryptoData).length > 0
            if (!hasData) {
                Qt.callLater(() => root.fetchPrices())
            } else {
                // Still schedule a background refresh for freshness
                refreshDelayTimer.restart()
            }
        }
    }

    Timer {
        id: refreshDelayTimer
        interval: 2000
        onTriggered: {
            if (root.coins.length > 0) root.fetchPrices()
        }
    }

    function fetchPrices() {
        if (coins.length === 0) return
        loading = true
        error = false
        priceProcess.url = "https://api.coingecko.com/api/v3/simple/price?ids=" + coins.join(",") + "&vs_currencies=usd&include_24hr_change=true"
        priceProcess.running = true
    }

    Process {
        id: priceProcess
        property string url: ""
        command: ["/usr/bin/curl", "-s", "--max-time", "10", url]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                if (text.length === 0) {
                    root.error = true
                    return
                }
                try {
                    root.cryptoData = JSON.parse(text)
                    root.error = false
                    root.saveCache()
                    // Start sparkline fetch
                    root.fetchSparklines()
                } catch (e) {
                    root.error = true
                }
            }
        }
    }

    property int _sparklineIdx: 0
    function fetchSparklines() {
        _sparklineIdx = 0
        sparklineTimer.start()
    }

    Timer {
        id: sparklineTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (root._sparklineIdx < root.coins.length) {
                const id = root.coins[root._sparklineIdx]
                sparklineProcess.coinId = id
                sparklineProcess.url = "https://api.coingecko.com/api/v3/coins/" + id + "/market_chart?vs_currency=usd&days=1"
                sparklineProcess.running = true
                root._sparklineIdx++
            } else {
                stop()
            }
        }
    }

    Process {
        id: sparklineProcess
        property string coinId: ""
        property string url: ""
        command: ["/usr/bin/curl", "-s", "--max-time", "10", url]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return
                try {
                    const data = JSON.parse(text)
                    if (data.prices && data.prices.length > 0) {
                        const prices = data.prices.map(p => p[1])
                        const min = Math.min.apply(null, prices)
                        const max = Math.max.apply(null, prices)
                        const range = max - min || 1
                        const step = Math.max(1, Math.floor(prices.length / 20))
                        const sampled = []
                        for (let i = 0; i < prices.length; i += step) {
                            sampled.push((prices[i] - min) / range)
                        }
                        const newData = Object.assign({}, root.sparklineData)
                        newData[sparklineProcess.coinId] = sampled.slice(-20)
                        root.sparklineData = newData
                        root.saveCache()
                    }
                } catch (e) {}
            }
        }
    }

    readonly property var coinSymbols: ({
        "bitcoin": "BTC", "ethereum": "ETH", "solana": "SOL", "cardano": "ADA",
        "dogecoin": "DOGE", "ripple": "XRP", "polkadot": "DOT", "avalanche-2": "AVAX",
        "chainlink": "LINK", "polygon": "MATIC", "litecoin": "LTC", "uniswap": "UNI",
        "stellar": "XLM", "monero": "XMR", "tron": "TRX", "toncoin": "TON",
        "shiba-inu": "SHIB", "pepe": "PEPE", "binancecoin": "BNB"
    })

    function getSymbol(id) { return coinSymbols[id] ?? id.toUpperCase().slice(0, 4) }
    function fmtPrice(p) {
        if (!p) return "---"
        return p >= 1000 ? p.toLocaleString(Qt.locale(), 'f', 0)
             : p >= 1 ? p.toLocaleString(Qt.locale(), 'f', 2)
             : p >= 0.01 ? p.toLocaleString(Qt.locale(), 'f', 4)
             : p.toLocaleString(Qt.locale(), 'f', 6)
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: parent.width
        implicitHeight: col.implicitHeight + 20
        radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
        color: "transparent"

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                MaterialSymbol {
                    text: "currency_bitcoin"
                    iconSize: 16
                    color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                }
                StyledText {
                    text: "Crypto"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                    color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
                }
                Item { Layout.fillWidth: true }

                Rectangle {
                    visible: root.loading
                    width: 6; height: 6; radius: 3
                    color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                    opacity: 0.6
                    SequentialAnimation on opacity {
                        running: root.loading && Appearance.animationsEnabled
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 400 }
                        NumberAnimation { to: 0.8; duration: 400 }
                    }
                }

                RippleButton {
                    implicitWidth: 24; implicitHeight: 24
                    buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover : Appearance.colors.colLayer1Hover
                    onClicked: root.fetchPrices()
                    contentItem: MaterialSymbol {
                        text: "refresh"; iconSize: 14
                        color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colOnLayer1Inactive
                    }
                    StyledToolTip { text: Translation.tr("Refresh") }
                }
            }

            Repeater {
                model: root.coins

                RowLayout {
                    id: row
                    required property string modelData
                    readonly property var d: root.cryptoData[modelData]
                    readonly property real price: d?.usd ?? 0
                    readonly property real chg: d?.usd_24h_change ?? 0
                    readonly property bool up: chg >= 0
                    readonly property var spark: root.sparklineData[modelData] ?? []

                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        text: root.getSymbol(row.modelData)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.family: Appearance.font.family.monospace
                        color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
                        Layout.preferredWidth: 36
                    }

                    StyledText {
                        text: "$" + root.fmtPrice(row.price)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.family: Appearance.font.family.numbers
                        color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
                        Layout.fillWidth: true
                    }

                    Graph {
                        visible: row.spark.length > 1
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        values: row.spark
                        color: row.up ? (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                                      : (Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError)
                        fillOpacity: 0.25
                        alignment: Graph.Alignment.Right
                    }

                    RowLayout {
                        visible: row.price > 0
                        spacing: 0
                        Layout.preferredWidth: 44
                        Layout.alignment: Qt.AlignVCenter

                        MaterialSymbol {
                            text: row.up ? "arrow_drop_up" : "arrow_drop_down"
                            iconSize: 14
                            color: row.up ? (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                                          : (Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError)
                        }
                        StyledText {
                            text: Math.abs(row.chg).toFixed(1) + "%"
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.family: Appearance.font.family.numbers
                            color: row.up ? (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                                          : (Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError)
                        }
                    }
                }
            }

            StyledText {
                visible: root.error && Object.keys(root.cryptoData).length === 0
                text: Translation.tr("Failed to load")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError
            }
            StyledText {
                visible: root.coins.length === 0
                text: Translation.tr("No coins configured")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
            }
        }
    }
}
