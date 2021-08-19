// This file is part of sfos-patch-keyboard-color-stock-emojis
// SPDX-FileCopyrightText: 2021 Mirian Margiani
// SPDX-License-Identifier: GPL-3.0-or-later
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import "patch_ichthyo_emoji.js" as Emoji

ConfigurationGroup {
    id: root
    path: '/apps/sailor-emoji'

    property string currentStyle: 'openmoji'
    property var recentlyUsedList: []
    property int layoutRows: 3
    property int keyWidth: 96 // punctuationKeyWidthNarrow is not defined in this context
    property int maxHistory: 40
    property bool _initialized: false

    signal variationChanged(var key)
    signal variationsChanged

    function init() {
        Emoji.dataBaseDirectory = StandardPaths.genericData
    }

    function getUrl(emojiCharacter, width, noGrow, maxSize) {
        if (!_initialized) init()
        return Emoji.parseSingleUrl(emojiCharacter, width,
                                    Emoji.Style[currentStyle],
                                    (!!noGrow), (!!noGrow) ?
                                        (maxSize !== undefined ? maxSize :width) :
                                        undefined
                                    ).text
    }

    function saveVariation(base, selected) {
        variations.setValue(base, selected)
    }

    function getVariation(base) {
        return variations.value(base, base)
    }

    function clearRecently() {
        recentlyUsedConfig.value = []
    }

    function removeRecently(index) {
        var list = recentlyUsedConfig.value.slice()
        list.splice(index, 1)
        recentlyUsedConfig.value = list
    }

    function saveRecently(emoji, index) {
        // We copy the selected emoji to the beginning of the
        // list instead of moving it. The user may want to send the same
        // emoji multiple times without having to move the view, but the
        // selected emoji should still be promoted to the beginning of the list.

        /*
        click = click a suggestion, i.e. with index
        add = normal key stroke, i.e. no index
        (x) = inserted
        [x] = removed
        ...|... = the first part are 'favorites', the second part is the rest
                  Emojis may be in the first and second part, but must not be
                  duplicated inside of a part.

        -empty-
        add 1 (no index):       (1)
        click 1:                1                       list was short, fill it
        add 2-9-0:              1(2345|67890)           -"-
        click 2:                12345|67890             2 was in first, skip
        click 7:                (7)1234|56789[0]        7 was not in first, insert and shift
        add x:                  (x)7123|45678[9]        x -"-
        click 4:                (4)x712|34567[8]        4 -"-
        add x:                  4x712|34567             x was in first, skip
        add 2:                  4x712|34567             2 -"-
        add 3:                  (3)4x71|2[3]456         3 was not in first, insert and deduplicate
        click the second 4:     34x71|2456              4 was in first, skip
        click the first 4:      34x71|2[4]56            4 was in first, deduplicate
        */

        var favoritesCount = Math.ceil(maxHistory/4)
        var full = recentlyUsedList.slice() // copy

        var keepAll = false
        var insert = false
        var deduplicate = false
        var shrinkToBounds = true
        var first = full.slice(0, favoritesCount)
        var rest = full.slice(favoritesCount)

        if (full.length <= favoritesCount) {
            shrinkToBounds = false // don't, as there's nothing to shrink yet
            if (full.indexOf(emoji) < 0) {
                // insert the new emoji at the front and let the list grow
                // over favoritesCount if it may
                insert = true
            } else {
                keepAll = true // do nothing so the emoji keeps its position
            }
        } else {
            // we assume any given index is correct, i.e. the emoji
            // exists at this position; we skip `anyIndexOf(emoji)===index`
            if (index >= 0) {
                if (index < favoritesCount) { // in first
                    // in first: remove any occurrence from the rest and keep the position in first
                    deduplicate = true
                } else if (index >= favoritesCount) { // in rest
                    shrinkToBounds = false // don't, to make sure we don't lose an emoji
                                           // (at the end of the list) that the user wanted to use
                    if (first.indexOf(emoji) < 0) {
                        // not in first: insert but keep in rest
                        insert = true
                    } else {
                        // in rest and in first: keep everything
                        keepAll = true
                    }
                }
            } else { // no index given
                if (first.indexOf(emoji) < 0) {
                    // not in first: insert in first and deduplicate rest
                    insert = true
                    deduplicate = true
                } else {
                    // in first: deduplicate rest
                    deduplicate = true
                }
            }
        }

        // Writing directly fails. We have to go through a separate
        // ConfigurationValue, otherwise the new value will be ignored.
        // setValue('recentlyUsedList', list)
        function _dedup(e) { return e !== emoji }
        var result = []
        if (keepAll) {
            result = first.concat(rest)
        } else if (insert && !deduplicate) {
            result = [emoji].concat(first, rest)
        } else if (!insert && deduplicate) {
            result = first.concat(rest.filter(_dedup))
        } else if (insert && deduplicate) {
            result = [emoji].concat(first, rest.filter(_dedup))
        }

        if (shrinkToBounds) recentlyUsedConfig.value = result.slice(0, maxHistory)
        else recentlyUsedConfig.value = result
    }

    ConfigurationValue {
        id: recentlyUsedConfig
        key: '/apps/sailor-emoji/recentlyUsedList'
        defaultValue: []
    }

    ConfigurationGroup {
        id: variations
        // key: base emoji
        // value: last selected emoji variation
        path: 'selected_variations'
        onValueChanged: variationChanged(key)
        onValuesChanged: variationsChanged()
    }
}