/*
 * Copyright (C) 2018 Jolla ltd and/or its subsidiary(-ies). All rights reserved.
 *
 * Contact: Joona Petrell <joona.petrell@jollamobile.com>
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * Redistributions of source code must retain the above copyright notice, this list
 * of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list
 * of conditions and the following disclaimer in the documentation and/or other materials
 * provided with the distribution.
 * Neither the name of Jolla Ltd nor the names of its contributors may be
 * used to endorse or promote products derived from this software without specific
 * prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 * THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

// Modified for sfos-patch-keyboard-color-stock-emojis
// SPDX-FileCopyrightText: 2021 Mirian Margiani
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.0
import com.jolla.keyboard 1.0
import Sailfish.Silica 1.0
import ".."
import "../ichthyo_color_emojis"
import "patch_ichthyo_emoji_data.js" as EmojiData

KeyboardLayout {
    id: root
    splitSupported: false
    capsLockSupported: false
    onCurrentCategoryChanged: currentPage = 0
    type: 'emojis' // plural

    property string currentCategory: 'smileys-emotion'
    property int currentPage: 0

    readonly property int keysPerRow: Math.ceil(root.width/emojiKeyWidth)
//     readonly property int keysInLastRow: Math.floor((root.width-3*innerSettingsKeyWidth-
//                                                      2*outerSettingsKeyWidth)/emojiKeyWidth)
    readonly property int keysInLastRow: Math.floor((root.width-2*innerSettingsKeyWidth-
                                                     2*outerSettingsKeyWidth)/emojiKeyWidth)
    readonly property int keysPerPage: (keysPerRow*(emojiConfigItem.layoutRows-1)) + keysInLastRow
//     readonly property real innerSettingsKeyWidth: 0.9*punctuationKeyWidth
    readonly property real innerSettingsKeyWidth: punctuationKeyWidth
    readonly property real outerSettingsKeyWidth: shiftKeyWidth
    readonly property real emojiKeyWidth: emojiConfigItem.keyWidth
    readonly property int pageCount: Math.ceil(EmojiData.list[currentCategory].length / keysPerPage)
    readonly property int pageIndicatorHeight: 4

    function enableSearchMode() {
        // TODO
        return
    }

    function showConfigOverlay() {
        if (!configOverlayLoader.item) return
        configOverlayLoader.item.open = true
    }

    function defaultFor(what, fallback) {
        return (what === '' || typeof what === 'undefined') ? fallback : what
    }

    function showPreviousPage() {
        if (currentPage === 0) currentPage = pageCount-1
        else currentPage--
    }

    function showNextPage() {
        if (currentPage === pageCount-1) currentPage = 0
        else currentPage++
    }

    // TODO:
    // x license
    // x config button
    // x configure style
    // x only show suggestions for the emoji keyboard, not with disabled input method hint
    // x fix popper highlight
    // x save last used emojis
    // x save and show last used variations
    // x show last used emojis in suggestion bar
    // x show icons in suggestion bar
    // x variations
    // x fix missing emojis
    // o split -- no: would require too many patches
    // o page for last used -- no: use suggestion bar
    // - search feature

    Timer {
        id: pageRepeatTimer
        repeat: true
        interval: 200
        running: prevKey.pressed || nextKey.pressed
        onTriggered: {
            if (prevKey.pressed) showPreviousPage()
            else if (nextKey.pressed) showNextPage()
            else stop()
        }
    }

    EmojiConfig {
        id: emojiConfigItem
    }

    Repeater {
        id: mainRowsRepeater
        model: emojiConfigItem.layoutRows-1
        KeyboardRow {
            separateButtonSizes: true
            property int rowIndex: index
            Repeater {
                model: keysPerRow
                EmojiKey {
                    property int emojiIndex: currentPage*keysPerPage + parent.rowIndex*keysPerRow + index
                    property var keyData: defaultFor(EmojiData.list[currentCategory][emojiIndex], {e:''})
                    emoji: !!keyData ? keyData.e : ''
                    emojiConfig: emojiConfigItem
                    emojiVariations: !!keyData ? keyData.opts : []
                    enabled: emoji !== ''
                }
            }
        }
    }

    KeyboardRow {
        id: lastEmojiRow
        separateButtonSizes: true
        property int rowIndex: mainRowsRepeater.count

        FunctionKey {
            id: prevKey
            icon.source: "image://theme/icon-m-left" + (pressed ? ("?" + Theme.highlightColor) : "")
            repeat: true
            key: Qt.Key_unknown
            implicitWidth: outerSettingsKeyWidth
            background.visible: false
            onClicked: {
                pageRepeatTimer.stop()
                showPreviousPage()
            }
        }

        FunctionKey {
            id: nextKey
            icon.source: "image://theme/icon-m-right" + (pressed ? ("?" + Theme.highlightColor) : "")
            repeat: true
            key: Qt.Key_unknown
            implicitWidth: innerSettingsKeyWidth
            background.visible: false
            onClicked: {
                pageRepeatTimer.stop()
                showNextPage()
            }
        }

        Repeater {
            model: keysInLastRow
            EmojiKey {
                property int emojiIndex: currentPage*keysPerPage + parent.rowIndex*keysPerRow + index
                property var keyData: defaultFor(EmojiData.list[currentCategory][emojiIndex], {e:''})
                emoji: !!keyData ? keyData.e : ''
                emojiConfig: emojiConfigItem
                emojiVariations: !!keyData ? keyData.opts : []
                enabled: emoji !== ''
            }
        }

        //FunctionKey { // search button
            //repeat: false
            //key: Qt.Key_unknown
            //implicitWidth: innerSettingsKeyWidth
            //background.visible: false
            //// TODO Remove the highlight hack once FunctionKey uses Icon instead of Image
            //icon.source: "image://theme/icon-cover-search" + (pressed ? ("?" + Theme.highlightColor) : "")
            //onClicked: enableSearchMode()
        //}

        FunctionKey { // config button
            repeat: false
            key: Qt.Key_unknown
            implicitWidth: innerSettingsKeyWidth
            background.visible: false
            // TODO Remove the highlight hack once FunctionKey uses Icon instead of Image
            icon.source: "image://theme/icon-lock-settings" + (pressed ? ("?" + Theme.highlightColor) : "")
            onClicked: showConfigOverlay()
        }

        BackspaceKey {
            implicitHeight: outerSettingsKeyWidth
        }
    }

    Item {
        width: parent.width
        height: 0.01 // almost no height to not influence the keyboard height,
                     // but still be picked up by the column layout
        Row {
            height: pageIndicatorHeight
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: -height-Theme.paddingSmall
            }
            spacing: Theme.paddingSmall
            Repeater {
                model: pageCount
                Rectangle {
                    height: pageIndicatorHeight
                    width: Theme.paddingLarge
                    opacity: index === currentPage ? 0.6 : 0.17
                    color: index === currentPage ? Theme.highlightBackgroundColor : Theme.primaryColor
                }
            }
        }
    }

    KeyboardRow {
        id: bottomRow
        separateButtonSizes: true

        FunctionKey {
            // The language switcher popup is bound to the space key.
            // See KeyboardBase.qml for the relevant implementation.
            key: Qt.Key_Space
            caption: "ABC"
            implicitWidth: shiftKeyWidth
            keyType: KeyType.SymbolKey
            onClicked: canvas.switchToPreviousCharacterLayout()
        }

        Repeater {
            model: EmojiData.groups
            EmojiGroupKey {
                emoji: modelData.i
                isSelected: modelData.n === currentCategory
                onClicked: currentCategory = modelData.n
                verticalOffset: pageIndicatorHeight
                emojiConfig: emojiConfigItem
            }
        }

        EnterKey {
            implicitWidth: shiftKeyWidth
        }
    }

    Loader {
        id: configOverlayLoader
        asynchronous: true
        sourceComponent: Component {
            EmojiConfigOverlay {
                width: parent.width
                emojiConfig: emojiConfigItem
            }
        }
    }
}
