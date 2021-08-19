// This file is part of sfos-patch-keyboard-color-stock-emojis
// SPDX-FileCopyrightText: 2021 Mirian Margiani
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.0
import com.jolla.keyboard 1.0
import Sailfish.Silica 1.0
import ".."
import "patch_ichthyo_emoji.js" as Emoji

CharacterKey {
    id: key
    keyType: KeyType.CharacterKey
    text: commitText ? selectedEmoji : ''
    keyText: ''
    implicitWidth: punctuationKeyWidthNarrow
    opacity: enabled ? (pressed ? 0.6 : 1.0) : 0.3
    separator: enabled ? SeparatorState.AutomaticSeparator : -1
    onEmojiChanged: refresh()

    property string emoji: '' // <--- usage: set this instead of text/caption
    property string selectedEmoji: emoji // handled internally
    property var emojiVariations: [] // <--- usage: set this instead of accents
    property bool commitText: true // whether to actually write the emoji
    property EmojiConfig emojiConfig
    readonly property real iconMargins: Theme.paddingSmall

    function refresh() {
        if (!emojiConfig) return
        selectedEmoji = emojiConfig.getVariation(emoji)
    }

    onClicked: {
        if (!commitText || !emojiConfig) return
        emojiConfig.saveRecently(selectedEmoji)
    }

    Item {
        anchors {
            fill: parent
            margins: iconMargins
        }

        EmojiPlaceholder {
            anchors.fill: image
            enabled: key.enabled
            icon: image
        }

        Image {
            id: image
            anchors.centerIn: parent
            width: Math.min(parent.width-leftPadding-rightPadding,
                            parent.height-2*Theme.paddingSmall)
            height: width
            horizontalAlignment: Image.AlignHCenter
            verticalAlignment: Image.AlignVCenter
            asynchronous: true
            source: (!!emojiConfig) ? emojiConfig.getUrl(selectedEmoji, width) : ''
            visible: status === Image.Ready
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { FadeAnimator { } }
        }
    }

    Item {
        anchors {
            fill: parent
            verticalCenterOffset: -Theme.paddingSmall
        }
        clip: true
        visible: !!emojiVariations && emojiVariations.length > 1 && key.enabled // more than the base variant
        Rectangle {
            opacity: key.pressed ? 0.6 : 0.17
            color: key.pressed ? Theme.highlightBackgroundColor : Theme.primaryColor
            width: Theme.paddingMedium * 1.5
            height: width
            rotation: 45
            anchors {
                verticalCenter: parent.bottom
                horizontalCenter: parent.right
            }
        }
    }

    Connections {
        target: emojiConfig
        onVariationChanged: if (key === emoji) refresh()
    }
}