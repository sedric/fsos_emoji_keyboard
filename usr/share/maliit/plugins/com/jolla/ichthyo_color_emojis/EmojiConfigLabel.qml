// This file is part of sfos-patch-keyboard-color-stock-emojis
// SPDX-FileCopyrightText: 2021 Mirian Margiani
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.2
import Sailfish.Silica 1.0

// to be used for descriptions in EmojiConfigOverlay.qml
Label {
    width: parent.width - 2*Theme.horizontalPageMargin
    wrapMode: Text.Wrap
    font.pixelSize: Theme.fontSizeSmall
    anchors.horizontalCenter: parent.horizontalCenter
    color: Theme.secondaryHighlightColor
    linkColor: Theme.secondaryColor
    onLinkActivated: Qt.openUrlExternally(link)
    textFormat: Text.PlainText
}

