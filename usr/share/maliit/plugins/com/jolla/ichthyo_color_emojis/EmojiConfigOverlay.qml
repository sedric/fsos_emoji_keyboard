// This file is part of sfos-patch-keyboard-color-stock-emojis
// SPDX-FileCopyrightText: 2021 Mirian Margiani
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import com.jolla.keyboard 1.0
import Sailfish.Silica 1.0
import "patch_ichthyo_emoji.js" as Emoji

Item {
    id: root
    // do not set height from outside
    // - if hidden: almost no height to not influence the keyboard height,
    //   but still be picked up by the column layout
    height: _closedHeight
    width: parent.width
    enabled: height === _openedHeight
    Behavior on height { SmoothedAnimation { duration: 300 } }

    readonly property string patchVersion: "1.2.0-1 (e%1)".arg(Emoji.version) // <-- change on update
    property bool open: false // <-- change to show
    property EmojiConfig emojiConfig: null // <-- set from outside
    property real _closedHeight: 0.01
    property real _openedHeight: ((MInputMethodQuick.appOrientation % 180 === 0) ?
                                      Screen.height : Screen.width)

    readonly property bool _haveRecently: !!emojiConfig && emojiConfig.recentlyUsedList.length > 0
    property int _currentSelection: -1
    signal emojiClicked(var index)

    onEmojiClicked: _currentSelection = index
    onOpenChanged: {
        if (open) {
            openAnim.from = height
            openAnim.to = _openedHeight
            openAnim.start()
        } else {
            openAnim.from = height
            openAnim.to = _closedHeight
            openAnim.start()
        }
    }
    on_OpenedHeightChanged: {
        if (open) {
            openAnim.from = height
            openAnim.to = _openedHeight
            openAnim.start()
        }
    }

    MouseArea {
        anchors.fill: parent
        preventStealing: true
    }

    Timer {
        running: _currentSelection >= 0
        interval: 2500
        onTriggered: emojiClicked(-1) // reset selection
    }

    SmoothedAnimation {
        id: openAnim
        target: root
        duration: 120
        property: "height"
        from: _closedHeight
        to: _closedHeight
        onStopped: {
            // scroll to top without animation
            if (!open) flick.contentY = 0
        }
    }

    Label {
        id: closeLabelTop
        anchors {
            top: parent.top; topMargin: Theme.paddingLarge
            horizontalCenter: parent.horizontalCenter
        }
        font.pixelSize: Theme.fontSizeLarge
        color: Theme.secondaryColor
        text: "Close"
        opacity: flick.contentY > 0 ? 0.0 : (-1*flick.contentY)/250
    }

    Label {
        id: closeLabelBottom
        anchors {
            bottom: parent.bottom; bottomMargin: Theme.paddingLarge
            horizontalCenter: parent.horizontalCenter
        }
        font.pixelSize: Theme.fontSizeLarge
        color: Theme.secondaryColor
        text: "Close"
        opacity: ((flick.contentY+flick.height)<flick.contentHeight)
                 ? 0.0 : ((flick.contentY+flick.height)-flick.contentHeight)/250
    }

    SilicaFlickable {
        id: flick
        anchors.fill: parent
        opacity: (open && !openAnim.running) ? 1.0 : 0.0
        Behavior on opacity { FadeAnimator { duration: 200 } }
        VerticalScrollDecorator { flickable: flick }
        contentWidth: parent.width
        contentHeight: column.height

        boundsBehavior: Flickable.DragOverBounds
        onDraggingVerticallyChanged: {
            if (contentY < -150 || contentY+height > contentHeight+150) {
                open = false
            }
        }

        Column {
            id: column
            width: parent.width
            height: childrenRect.height

            PageHeader {
                id: header
                title: "Emoji configuration"
                description: "patch version %1".arg(patchVersion)

                IconButton {
                    parent: header.extraContent
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    icon.source: "image://theme/icon-m-dismiss"
                    onClicked: open = false
                }
            }

            SectionHeader {
                text: "Recently used"
            }

            Item {
                width: parent.width - 2*Theme.paddingLarge
                height: recentFlow.height
                anchors.horizontalCenter: parent.horizontalCenter
                visible: _haveRecently

                Rectangle {
                    anchors.fill: recentFlow
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.secondaryHighlightColor
                    radius: Theme.paddingLarge
                }

                Flow {
                    id: recentFlow
                    width: parent.width
                    spacing: Theme.paddingMedium
                    padding: Theme.paddingMedium

                    Repeater {
                        model: !!emojiConfig ? emojiConfig.recentlyUsedList : []
                        Item {
                            id: emoji
                            width: Theme.iconSizeSmallPlus
                            height: width

                            EmojiPlaceholder {
                                id: emojiPlaceholder
                                anchors.fill: emojiIcon
                                icon: emojiIcon
                                visible: !removeButton.visible
                            }

                            Image {
                                id: emojiIcon
                                anchors.fill: parent
                                horizontalAlignment: Image.AlignHCenter
                                verticalAlignment: Image.AlignVCenter
                                asynchronous: true
                                source: !!emojiConfig ? emojiConfig.getUrl(modelData, width,
                                                                           true, Theme.iconSizeSmallPlus) : ''
                                visible: status === Image.Ready && !removeButton.visible
                                opacity: visible ? 1.0 : 0.0
                                Behavior on opacity { FadeAnimator { } }
                            }

                            MouseArea {
                                enabled: !removeButton.visible
                                anchors.fill: emojiIcon
                                onClicked: emojiClicked(index)
                            }

                            IconButton {
                                id: removeButton
                                anchors.centerIn: parent
                                icon.source: "image://theme/icon-m-clear"
                                onClicked: {
                                    if (!emojiConfig) return
                                    emojiIcon.visible = false // hide doomed
                                    emojiPlaceholder.visible = false
                                    emojiClicked(-1) // reset selection
                                    emojiConfig.removeRecently(index)
                                }
                                enabled: visible
                                visible: _currentSelection === index
                                opacity: visible ? 1.0 : 0.0
                                Behavior on opacity { FadeAnimator { } }
                            }
                        }
                    }
                }
            }

            EmojiConfigLabel {
                visible: !_haveRecently
                text: "No recently used emojis have been collected yet."
            }

            Item { visible: _haveRecently; width: parent.width; height: Theme.paddingLarge }

            Button {
                visible: _haveRecently
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Clear recently used"
                onClicked: if (!!emojiConfig) emojiConfig.clearRecently()
            }

            Item { width: parent.width; height: 2*Theme.paddingLarge }

            SectionHeader {
                text: "Emoji styles"
            }

            EmojiConfigLabel {
                textFormat: Text.StyledText
                text: "You have to manually download and install an emoji set before you can use it. " +
                      "Please follow the instructions "+
                      "<a href='https://gitlab.com/rubdos/whisperfish-wiki/-/blob/master/Emojis.md'>" +
                      "in the Whisperfish wiki</a>."
            }

            Item { width: parent.width; height: Theme.paddingMedium }

            Repeater {
                model: {
                    var keys = Object.keys(Emoji.Style)
                    keys.splice(keys.indexOf('system'), 1)
                    return keys
                }
                BackgroundItem {
                    id: bgItem
                    width: parent.width
                    height: Theme.itemSizeSmall
                    property string name: Emoji.Style[modelData].name
                    property string type: modelData
                    property bool isSelected: (!!emojiConfig && type === emojiConfig.currentStyle)
                    property int installedState: (root.open || isSelected) ? Emoji.isInstalled(Emoji.Style[modelData], true) : -1
                    highlighted: down || isSelected

                    Label {
                        id: styleLabel
                        anchors.centerIn: parent
                        width: parent.width - 2*Theme.horizontalPageMargin
                        text: bgItem.name
                    }

                    Label {
                        anchors {
                            baseline: styleLabel.baseline
                            right: parent.right; rightMargin: Theme.horizontalPageMargin
                        }
                        text: {
                            if (bgItem.installedState === 0) "installed"
                            else if (bgItem.installedState < 0) "not installed"
                            else "incomplete"
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    }

                    onClicked: {
                        if (!!emojiConfig) emojiConfig.currentStyle = type
                    }
                }
            }

            // The ComboBox breaks the whole keyboard.
            /* ComboBox {
                id: stylesCombo
                property var availableStyles: {
                    var keys = Object.keys(Emoji.Style)
                    keys.splice(keys.indexOf('system'), 1)
                    ready = true
                    // currentIndex = keys.indexOf(emojiConfig.currentStyle)
                    return keys
                }
                property bool ready: false
                width: parent.width
                label: "Current style"
                description: "Monochrome styles are not supported."
                currentIndex: -1
                menu: ContextMenu {
                    property var __silica_applicationwindow_instance: {_dimScreen:false}
                    Repeater {
                        model: stylesCombo.availableStyles
                        MenuItem {
                            text: Emoji.Style[modelData].name; property string type: modelData
                            Component.onCompleted: {
                                if (emojiConfig.currentStyle === modelData) {
                                    stylesCombo.currentIndex = index
                                }
                            }
                        }
                    }
                }

                onCurrentIndexChanged:  {
                    if (!ready || currentIndex < 0 || !availableStyles) return
                    emojiConfig.currentStyle = availableStyles[currentIndex]
                }
            } */

            Item { width: parent.width; height: 2*Theme.paddingLarge }

            SectionHeader {
                text: "Keyboard layout"
            }

            EmojiConfigLabel {
                text: "You have to switch back and forth between the emoji "+
                      "keyboard and a text keyboard for any changes to take effect."
            }

            Slider {
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
                minimumValue: 2
                maximumValue: 5
                value: emojiConfig.layoutRows
                stepSize: 1.0
                valueText: "%1 rows".arg(value)
                label: "Number of keyboard rows"
                onReleased: {
                    if (!emojiConfig) return
                    // update as seldom as possible
                    if (value !== emojiConfig.layoutRows) {
                        emojiConfig.layoutRows = value
                    }
                }
            }

            EmojiConfigLabel {
                text: "Adjust the number of keyboard rows to the number of rows " +
                      "in your default keyboard. Switching between keyboards can be " +
                      "slow if they have different heights."
            }

            Slider {
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
                minimumValue: punctuationKeyWidthNarrow
                maximumValue: functionKeyWidth
                value: emojiConfig.keyWidth
                stepSize: 1.0
                valueText: "%1px".arg(value)
                label: "Emoji key width"
                onReleased: {
                    if (!emojiConfig) return
                    // update as seldom as possible
                    if (value !== emojiConfig.keyWidth) {
                        emojiConfig.keyWidth = value
                    }
                }
            }

            EmojiConfigLabel {
                text: "Some emoji styles like OpenMoji may require larger keys to " +
                      "be readable. Note that the effective emoji size is restricted by " +
                      "the row height which cannot be changed."
            }

            /*Item { width: parent.width; height: 1*Theme.paddingLarge }

            Switch {
                id: leftSwitch
                onCheckedChanged: if (checked) rightSwitch.checked = false
            }

            Switch {
                id: rightSwitch
                onCheckedChanged: if (checked) leftSwitch.checked = false
            }

            Switch {
                id: bothSwitch
            }*/

            Item { width: parent.width; height: 2*Theme.paddingLarge }

            SectionHeader {
                text: "About"
            }

            EmojiConfigLabel {
                font.pixelSize: Theme.fontSizeExtraSmall
                textFormat: Text.StyledText
                text: "Copyright 2021 Mirian Margiani<br>" +
                      "The emoji keyboard patch is currently released under the terms of the " +
                      "GNU GPL version 3 or later. The source code is available " +
                      "<a href='https://github.com/ichthyosaurus/sailfish-public-patch-sources'>on Github</a>. " +
                      "This is free software: you are free to change and redistribute it. " +
                      "There is no warranty, to the extent permitted by law."
            }

            Item { width: parent.width; height: Theme.paddingLarge }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Close"
                onClicked: open = false
            }

            Item { width: parent.width; height: Theme.horizontalPageMargin }
        }
    }
}