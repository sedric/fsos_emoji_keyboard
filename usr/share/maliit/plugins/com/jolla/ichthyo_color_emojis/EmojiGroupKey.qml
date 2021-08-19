// This file is part of sfos-patch-keyboard-color-stock-emojis
// SPDX-FileCopyrightText: 2021 Mirian Margiani
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."

EmojiKey {
    id: key
    repeat: false
    key: Qt.Key_unknown
    implicitWidth: punctuationKeyWidthNarrow
    showPopper: false
    separator: -1
    showHighlight: false
    commitText: false
    emoji: '' // <--- usage: set this instead of text/caption
    emojiConfig: null // <--- usage: has to be set by the layout

    property bool isSelected: false
    property real verticalOffset: 0

    Rectangle {
        id: bg
        anchors {
            margins: (key.height >= (key.width+2*Theme.paddingMedium)) ? Theme.paddingMedium : iconMargins/2
            top: parent.top; topMargin: Theme.paddingMedium+verticalOffset
            bottom: parent.bottom; bottomMargin: Theme.paddingMedium // not (-verticalOffset) to keep it aligned
            left: parent.left; leftMargin: iconMargins/2
            right: parent.right; rightMargin: iconMargins/2
        }
        opacity: {
            if (parent.pressed) 0.6
            else if (isSelected) 0.35
            else 0.17
        }
        color: parent.pressed ? Theme.highlightBackgroundColor : Theme.primaryColor
        radius: geometry.keyRadius
    }
}