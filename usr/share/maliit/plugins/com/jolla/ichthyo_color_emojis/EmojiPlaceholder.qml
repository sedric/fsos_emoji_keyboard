// This file is part of sfos-patch-keyboard-color-stock-emojis
// SPDX-FileCopyrightText: 2021 Mirian Margiani
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.0
import Sailfish.Silica 1.0

Item {
    id: root
    property Image icon
    property bool enabled: true

    Rectangle {
        id: placeholder
        anchors.fill: parent
        radius: width
        color: Theme.primaryColor
        visible: enabled && icon.status !== Image.Ready &&
                 icon.status !== Image.Loading // to avoid flickering
        opacity: visible ? 0.16 : 0.0
    }

    Label {
        text: '?'
        anchors.centerIn: placeholder
        visible: placeholder.visible && icon.status === Image.Null
    }

    Label {
        text: '!'
        font.bold: true
        anchors.centerIn: placeholder
        visible: placeholder.visible && icon.status === Image.Error
    }
}
