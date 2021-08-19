/*
  Original license:

  Copyright (c) 2018 Twitter, Inc and other contributors

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
/*

/*! Copyright Twitter Inc. and other contributors. Licensed under MIT *//*
  https://github.com/twitter/twemoji/blob/gh-pages/LICENSE

  Modified and relicensed under AGPL v3+ for use in Whisperfish by Mirian Margiani (2021).
  Based on: https://github.com/twitter/twemoji/blob/64b63c21b8a1524dd4bbfa112e826e76348a7219/v/13.0.1/twemoji.js

  How to update:
  - Update the source link.
  - Update the regex (var re).
  - Check if any of the variables/functions has changed. Currently used parts:
    - variables: re, UFE0Fg, U200D
    - functions: grabTheRightIcon, parseString (adapted), toCodePoint, parse (adapted)
  - Update this guide if necessary.
*/

// +++ WF: ↓↓ Whisperfish configuration
.pragma library // load the file only once
// TODO: We should provide a way for users to download emoji sets to WF's directory
//       in $HOME/.local/share (in-app for open sets, and a guide for proprietary sets).
// TODO: We need an entry in the settings page to configure the emoji style.
// TODO: handle missing icons/characters instead of showing an empty space
// TODO: Is there a way to include official Signal emojis?

// NOTE This version string must be updated with each change to the script.
// We strictly follow Semantic Versioning 2.0.0, https://semver.org/.
// While at version < 1.0.0, the public API may change at any time.
var version = '0.1.0'

// Data directories: emojis are by default located in StandardPaths.data/emojis,
// which is typically $HOME/.local/share/sailor-emoji. The base directory has to
// be initialized from QML, as this script cannot access the StandardPaths object.
var dataBaseDirectory = '' // e.g. /home/nemo/.local/share; base path to emoji sources
var emojiSubDirectory = 'sailor-emoji' // subdirectory below DataBaseDirectory

// Emoji styles: emojis can be in raster or vector format. Raster emojis are
// required in multiple resolutions.
// Path: base/subdir/<style>/<version>/[<resolution>/]<codepoint>.<ext>
var Style = { // could be initialized on startup with user-configured values
    'openmoji': { name: 'OpenMoji', dir: 'openmoji/13.0.0', ext: 'svg', type: 'v' }, // CC-BY-SA 4.0
    'twemoji': { name: 'Twemoji', dir: 'twemoji/13.0.1', ext: 'svg', type: 'v' }, // CC-BY-SA 4.0
    'whatsapp': { name: 'Whatsapp', dir: 'whatsapp/2.20.206.24', ext: 'png', type: 'r' }, // proprietary
    'system': { name: 'System', dir: '', ext: '', type: 's' }
}

// Required raster resolutions: Qt cannot scale inline images up, only down.
// Sizes available from Emojipedia: [160, 144, 120, 72, 60]; maybe [120, 60] is enough?
//var rasterSizes = [144, 120, 72, 60] // decreasing
var rasterSizes = [144, 72, 60] // decreasing
var rasterSizesCache = {}

// Styles are checked once (raster styles once per resolution) and the results
// are cached. No emojis will be replaced if a style is not available,
// i.e. the system font will be used. Emojis are always counted, though.
var styleStatusCache = {}

// Check if a style is installed.
// Return:
// - <0 = not installed
// -  0 = fully installed
// - >0 = incomplete, i.e. raster sizes are missing
function isInstalled(style, noCache) {
    if (style.type === 's') return 0
    var status = 0, check = {}
    if (style.type === 'r') {
        for (var i in rasterSizes) {
            check = getParseSettings(style, rasterSizes[i], rasterSizes[i], true, noCache)
            if (check.useSystem === true) status += 1
        }
        if (status === rasterSizes.length) {
            // no sizes found, i.e. not installed
            status = -1
        }
    } else {
        check = getParseSettings(style, rasterSizes[i], rasterSizes[i], true, noCache)
        if (check.useSystem === true) status = -1
    }
    return status
}

function checkStyle(path, style, noCache) {
  // TODO This is a hack and should be implemented in rust for better checks
  // and better performance. Ideally we should check if a set is complete...
  if ((!noCache) && styleStatusCache.hasOwnProperty(path)) {
    return styleStatusCache[path];
  }
  if (style.dir === '') { // use system font
      styleStatusCache[path] = false;
      return false;
  }

  var cleanPath = path;
  if (/^file:\/\//.test(path)) cleanPath = path.substr(7);
  var xhr = new XMLHttpRequest, success = false;
  xhr.open("GET", cleanPath+'/2764.'+style.ext, false); // fetch 'heart' synchronously
  xhr.send();

  if (xhr.status === 200) success = true;
  if (!success) console.error("failed to load emoji style at", cleanPath+'/2764.'+style.ext);
  styleStatusCache[path] = success;
  return success;
}

function getParseSettings(style, size, maxRasterSize, noGrow, noCache) {
    var sourceSize = -1, stylePath = '', useSystem = false, effectiveSize = 0;
    if (noGrow === true) {
      effectiveSize = Math.round(size);
    } else {
      effectiveSize = Math.round(1.15*size);
    }

    if (style.type === 'r' /* raster */) {
      if (maxRasterSize > 0) {
        effectiveSize = maxRasterSize
      }

      // We have to choose the best source resolution for raster emojis.
      // Qt only supports downscaling of inline images, so we select the
      // closest resolution above the desired size.

      var cached = (!!noCache) ? undefined : rasterSizesCache[effectiveSize]
      if (cached !== undefined) {
        sourceSize = cached.source
        stylePath = cached.path
        effectiveSize = cached.effective
      } else {
        var key = effectiveSize
        // Reset the desired size to the largest available size.
        if (effectiveSize > rasterSizes[0]) effectiveSize = rasterSizes[0]

        for (var i in rasterSizes) {
          // Select the new size if it is >= the desired size.
          if (rasterSizes[i] >= effectiveSize) sourceSize = rasterSizes[i]
        }

        // Reset the source size to the smallest available size if none was found.
        // Reset the effective size if the fallback resolution too small.
        if (sourceSize < 0) sourceSize = rasterSizes[rasterSizes.length-1]
        if (effectiveSize > sourceSize) effectiveSize = sourceSize

        stylePath = Qt.resolvedUrl(''.concat(dataBaseDirectory, '/', emojiSubDirectory, '/',
                                             style.dir, '/', sourceSize))

        // cache the result using the original effectiveSize as key
        rasterSizesCache[key] = {source: sourceSize, effective: effectiveSize, path: stylePath}
      }
    } else if (style.type === 's') {
      useSystem = true
    } else {
      stylePath = Qt.resolvedUrl(''.concat(dataBaseDirectory, '/', emojiSubDirectory, '/',
                                           style.dir))
    }

    if (!useSystem && !checkStyle(stylePath, style, noCache)) {
        useSystem = true;
    }

    return {
        useSystem: useSystem,
        stylePath: stylePath,
        effectiveSize: effectiveSize,
    }
}
// +++ WF: ↑↑ Whisperfish configuration

// +++ WF: added 'var', removed comma
// RegExp based on emoji's official Unicode standards
// http://www.unicode.org/Public/UNIDATA/EmojiSources.txt
var re = /(?:\ud83d\udc68\ud83c\udffb\u200d\ud83e\udd1d\u200d\ud83d\udc68\ud83c[\udffc-\udfff]|\ud83d\udc68\ud83c\udffc\u200d\ud83e\udd1d\u200d\ud83d\udc68\ud83c[\udffb\udffd-\udfff]|\ud83d\udc68\ud83c\udffd\u200d\ud83e\udd1d\u200d\ud83d\udc68\ud83c[\udffb\udffc\udffe\udfff]|\ud83d\udc68\ud83c\udffe\u200d\ud83e\udd1d\u200d\ud83d\udc68\ud83c[\udffb-\udffd\udfff]|\ud83d\udc68\ud83c\udfff\u200d\ud83e\udd1d\u200d\ud83d\udc68\ud83c[\udffb-\udffe]|\ud83d\udc69\ud83c\udffb\u200d\ud83e\udd1d\u200d\ud83d\udc68\ud83c[\udffc-\udfff]|\ud83d\udc69\ud83c\udffb\u200d\ud83e\udd1d\u200d\ud83d\udc69\ud83c[\udffc-\udfff]|\ud83d\udc69\ud83c\udffc\u200d\ud83e\udd1d\u200d\ud83d\udc68\ud83c[\udffb\udffd-\udfff]|\ud83d\udc69\ud83c\udffc\u200d\ud83e\udd1d\u200d\ud83d\udc69\ud83c[\udffb\udffd-\udfff]|\ud83d\udc69\ud83c\udffd\u200d\ud83e\udd1d\u200d\ud83d\udc68\ud83c[\udffb\udffc\udffe\udfff]|\ud83d\udc69\ud83c\udffd\u200d\ud83e\udd1d\u200d\ud83d\udc69\ud83c[\udffb\udffc\udffe\udfff]|\ud83d\udc69\ud83c\udffe\u200d\ud83e\udd1d\u200d\ud83d\udc68\ud83c[\udffb-\udffd\udfff]|\ud83d\udc69\ud83c\udffe\u200d\ud83e\udd1d\u200d\ud83d\udc69\ud83c[\udffb-\udffd\udfff]|\ud83d\udc69\ud83c\udfff\u200d\ud83e\udd1d\u200d\ud83d\udc68\ud83c[\udffb-\udffe]|\ud83d\udc69\ud83c\udfff\u200d\ud83e\udd1d\u200d\ud83d\udc69\ud83c[\udffb-\udffe]|\ud83e\uddd1\ud83c\udffb\u200d\ud83e\udd1d\u200d\ud83e\uddd1\ud83c[\udffb-\udfff]|\ud83e\uddd1\ud83c\udffc\u200d\ud83e\udd1d\u200d\ud83e\uddd1\ud83c[\udffb-\udfff]|\ud83e\uddd1\ud83c\udffd\u200d\ud83e\udd1d\u200d\ud83e\uddd1\ud83c[\udffb-\udfff]|\ud83e\uddd1\ud83c\udffe\u200d\ud83e\udd1d\u200d\ud83e\uddd1\ud83c[\udffb-\udfff]|\ud83e\uddd1\ud83c\udfff\u200d\ud83e\udd1d\u200d\ud83e\uddd1\ud83c[\udffb-\udfff]|\ud83e\uddd1\u200d\ud83e\udd1d\u200d\ud83e\uddd1|\ud83d\udc6b\ud83c[\udffb-\udfff]|\ud83d\udc6c\ud83c[\udffb-\udfff]|\ud83d\udc6d\ud83c[\udffb-\udfff]|\ud83d[\udc6b-\udc6d])|(?:\ud83d[\udc68\udc69]|\ud83e\uddd1)(?:\ud83c[\udffb-\udfff])?\u200d(?:\u2695\ufe0f|\u2696\ufe0f|\u2708\ufe0f|\ud83c[\udf3e\udf73\udf7c\udf84\udf93\udfa4\udfa8\udfeb\udfed]|\ud83d[\udcbb\udcbc\udd27\udd2c\ude80\ude92]|\ud83e[\uddaf-\uddb3\uddbc\uddbd])|(?:\ud83c[\udfcb\udfcc]|\ud83d[\udd74\udd75]|\u26f9)((?:\ud83c[\udffb-\udfff]|\ufe0f)\u200d[\u2640\u2642]\ufe0f)|(?:\ud83c[\udfc3\udfc4\udfca]|\ud83d[\udc6e\udc70\udc71\udc73\udc77\udc81\udc82\udc86\udc87\ude45-\ude47\ude4b\ude4d\ude4e\udea3\udeb4-\udeb6]|\ud83e[\udd26\udd35\udd37-\udd39\udd3d\udd3e\uddb8\uddb9\uddcd-\uddcf\uddd6-\udddd])(?:\ud83c[\udffb-\udfff])?\u200d[\u2640\u2642]\ufe0f|(?:\ud83d\udc68\u200d\u2764\ufe0f\u200d\ud83d\udc8b\u200d\ud83d\udc68|\ud83d\udc68\u200d\ud83d\udc68\u200d\ud83d\udc66\u200d\ud83d\udc66|\ud83d\udc68\u200d\ud83d\udc68\u200d\ud83d\udc67\u200d\ud83d[\udc66\udc67]|\ud83d\udc68\u200d\ud83d\udc69\u200d\ud83d\udc66\u200d\ud83d\udc66|\ud83d\udc68\u200d\ud83d\udc69\u200d\ud83d\udc67\u200d\ud83d[\udc66\udc67]|\ud83d\udc69\u200d\u2764\ufe0f\u200d\ud83d\udc8b\u200d\ud83d[\udc68\udc69]|\ud83d\udc69\u200d\ud83d\udc69\u200d\ud83d\udc66\u200d\ud83d\udc66|\ud83d\udc69\u200d\ud83d\udc69\u200d\ud83d\udc67\u200d\ud83d[\udc66\udc67]|\ud83d\udc68\u200d\u2764\ufe0f\u200d\ud83d\udc68|\ud83d\udc68\u200d\ud83d\udc66\u200d\ud83d\udc66|\ud83d\udc68\u200d\ud83d\udc67\u200d\ud83d[\udc66\udc67]|\ud83d\udc68\u200d\ud83d\udc68\u200d\ud83d[\udc66\udc67]|\ud83d\udc68\u200d\ud83d\udc69\u200d\ud83d[\udc66\udc67]|\ud83d\udc69\u200d\u2764\ufe0f\u200d\ud83d[\udc68\udc69]|\ud83d\udc69\u200d\ud83d\udc66\u200d\ud83d\udc66|\ud83d\udc69\u200d\ud83d\udc67\u200d\ud83d[\udc66\udc67]|\ud83d\udc69\u200d\ud83d\udc69\u200d\ud83d[\udc66\udc67]|\ud83c\udff3\ufe0f\u200d\u26a7\ufe0f|\ud83c\udff3\ufe0f\u200d\ud83c\udf08|\ud83c\udff4\u200d\u2620\ufe0f|\ud83d\udc15\u200d\ud83e\uddba|\ud83d\udc3b\u200d\u2744\ufe0f|\ud83d\udc41\u200d\ud83d\udde8|\ud83d\udc68\u200d\ud83d[\udc66\udc67]|\ud83d\udc69\u200d\ud83d[\udc66\udc67]|\ud83d\udc6f\u200d\u2640\ufe0f|\ud83d\udc6f\u200d\u2642\ufe0f|\ud83e\udd3c\u200d\u2640\ufe0f|\ud83e\udd3c\u200d\u2642\ufe0f|\ud83e\uddde\u200d\u2640\ufe0f|\ud83e\uddde\u200d\u2642\ufe0f|\ud83e\udddf\u200d\u2640\ufe0f|\ud83e\udddf\u200d\u2642\ufe0f|\ud83d\udc08\u200d\u2b1b)|[#*0-9]\ufe0f?\u20e3|(?:[©®\u2122\u265f]\ufe0f)|(?:\ud83c[\udc04\udd70\udd71\udd7e\udd7f\ude02\ude1a\ude2f\ude37\udf21\udf24-\udf2c\udf36\udf7d\udf96\udf97\udf99-\udf9b\udf9e\udf9f\udfcd\udfce\udfd4-\udfdf\udff3\udff5\udff7]|\ud83d[\udc3f\udc41\udcfd\udd49\udd4a\udd6f\udd70\udd73\udd76-\udd79\udd87\udd8a-\udd8d\udda5\udda8\uddb1\uddb2\uddbc\uddc2-\uddc4\uddd1-\uddd3\udddc-\uddde\udde1\udde3\udde8\uddef\uddf3\uddfa\udecb\udecd-\udecf\udee0-\udee5\udee9\udef0\udef3]|[\u203c\u2049\u2139\u2194-\u2199\u21a9\u21aa\u231a\u231b\u2328\u23cf\u23ed-\u23ef\u23f1\u23f2\u23f8-\u23fa\u24c2\u25aa\u25ab\u25b6\u25c0\u25fb-\u25fe\u2600-\u2604\u260e\u2611\u2614\u2615\u2618\u2620\u2622\u2623\u2626\u262a\u262e\u262f\u2638-\u263a\u2640\u2642\u2648-\u2653\u2660\u2663\u2665\u2666\u2668\u267b\u267f\u2692-\u2697\u2699\u269b\u269c\u26a0\u26a1\u26a7\u26aa\u26ab\u26b0\u26b1\u26bd\u26be\u26c4\u26c5\u26c8\u26cf\u26d1\u26d3\u26d4\u26e9\u26ea\u26f0-\u26f5\u26f8\u26fa\u26fd\u2702\u2708\u2709\u270f\u2712\u2714\u2716\u271d\u2721\u2733\u2734\u2744\u2747\u2757\u2763\u2764\u27a1\u2934\u2935\u2b05-\u2b07\u2b1b\u2b1c\u2b50\u2b55\u3030\u303d\u3297\u3299])(?:\ufe0f|(?!\ufe0e))|(?:(?:\ud83c[\udfcb\udfcc]|\ud83d[\udd74\udd75\udd90]|[\u261d\u26f7\u26f9\u270c\u270d])(?:\ufe0f|(?!\ufe0e))|(?:\ud83c[\udf85\udfc2-\udfc4\udfc7\udfca]|\ud83d[\udc42\udc43\udc46-\udc50\udc66-\udc69\udc6e\udc70-\udc78\udc7c\udc81-\udc83\udc85-\udc87\udcaa\udd7a\udd95\udd96\ude45-\ude47\ude4b-\ude4f\udea3\udeb4-\udeb6\udec0\udecc]|\ud83e[\udd0c\udd0f\udd18-\udd1c\udd1e\udd1f\udd26\udd30-\udd39\udd3d\udd3e\udd77\uddb5\uddb6\uddb8\uddb9\uddbb\uddcd-\uddcf\uddd1-\udddd]|[\u270a\u270b]))(?:\ud83c[\udffb-\udfff])?|(?:\ud83c\udff4\udb40\udc67\udb40\udc62\udb40\udc65\udb40\udc6e\udb40\udc67\udb40\udc7f|\ud83c\udff4\udb40\udc67\udb40\udc62\udb40\udc73\udb40\udc63\udb40\udc74\udb40\udc7f|\ud83c\udff4\udb40\udc67\udb40\udc62\udb40\udc77\udb40\udc6c\udb40\udc73\udb40\udc7f|\ud83c\udde6\ud83c[\udde8-\uddec\uddee\uddf1\uddf2\uddf4\uddf6-\uddfa\uddfc\uddfd\uddff]|\ud83c\udde7\ud83c[\udde6\udde7\udde9-\uddef\uddf1-\uddf4\uddf6-\uddf9\uddfb\uddfc\uddfe\uddff]|\ud83c\udde8\ud83c[\udde6\udde8\udde9\uddeb-\uddee\uddf0-\uddf5\uddf7\uddfa-\uddff]|\ud83c\udde9\ud83c[\uddea\uddec\uddef\uddf0\uddf2\uddf4\uddff]|\ud83c\uddea\ud83c[\udde6\udde8\uddea\uddec\udded\uddf7-\uddfa]|\ud83c\uddeb\ud83c[\uddee-\uddf0\uddf2\uddf4\uddf7]|\ud83c\uddec\ud83c[\udde6\udde7\udde9-\uddee\uddf1-\uddf3\uddf5-\uddfa\uddfc\uddfe]|\ud83c\udded\ud83c[\uddf0\uddf2\uddf3\uddf7\uddf9\uddfa]|\ud83c\uddee\ud83c[\udde8-\uddea\uddf1-\uddf4\uddf6-\uddf9]|\ud83c\uddef\ud83c[\uddea\uddf2\uddf4\uddf5]|\ud83c\uddf0\ud83c[\uddea\uddec-\uddee\uddf2\uddf3\uddf5\uddf7\uddfc\uddfe\uddff]|\ud83c\uddf1\ud83c[\udde6-\udde8\uddee\uddf0\uddf7-\uddfb\uddfe]|\ud83c\uddf2\ud83c[\udde6\udde8-\udded\uddf0-\uddff]|\ud83c\uddf3\ud83c[\udde6\udde8\uddea-\uddec\uddee\uddf1\uddf4\uddf5\uddf7\uddfa\uddff]|\ud83c\uddf4\ud83c\uddf2|\ud83c\uddf5\ud83c[\udde6\uddea-\udded\uddf0-\uddf3\uddf7-\uddf9\uddfc\uddfe]|\ud83c\uddf6\ud83c\udde6|\ud83c\uddf7\ud83c[\uddea\uddf4\uddf8\uddfa\uddfc]|\ud83c\uddf8\ud83c[\udde6-\uddea\uddec-\uddf4\uddf7-\uddf9\uddfb\uddfd-\uddff]|\ud83c\uddf9\ud83c[\udde6\udde8\udde9\uddeb-\udded\uddef-\uddf4\uddf7\uddf9\uddfb\uddfc\uddff]|\ud83c\uddfa\ud83c[\udde6\uddec\uddf2\uddf3\uddf8\uddfe\uddff]|\ud83c\uddfb\ud83c[\udde6\udde8\uddea\uddec\uddee\uddf3\uddfa]|\ud83c\uddfc\ud83c[\uddeb\uddf8]|\ud83c\uddfd\ud83c\uddf0|\ud83c\uddfe\ud83c[\uddea\uddf9]|\ud83c\uddff\ud83c[\udde6\uddf2\uddfc]|\ud83c[\udccf\udd8e\udd91-\udd9a\udde6-\uddff\ude01\ude32-\ude36\ude38-\ude3a\ude50\ude51\udf00-\udf20\udf2d-\udf35\udf37-\udf7c\udf7e-\udf84\udf86-\udf93\udfa0-\udfc1\udfc5\udfc6\udfc8\udfc9\udfcf-\udfd3\udfe0-\udff0\udff4\udff8-\udfff]|\ud83d[\udc00-\udc3e\udc40\udc44\udc45\udc51-\udc65\udc6a\udc6f\udc79-\udc7b\udc7d-\udc80\udc84\udc88-\udca9\udcab-\udcfc\udcff-\udd3d\udd4b-\udd4e\udd50-\udd67\udda4\uddfb-\ude44\ude48-\ude4a\ude80-\udea2\udea4-\udeb3\udeb7-\udebf\udec1-\udec5\uded0-\uded2\uded5-\uded7\udeeb\udeec\udef4-\udefc\udfe0-\udfeb]|\ud83e[\udd0d\udd0e\udd10-\udd17\udd1d\udd20-\udd25\udd27-\udd2f\udd3a\udd3c\udd3f-\udd45\udd47-\udd76\udd78\udd7a-\uddb4\uddb7\uddba\uddbc-\uddcb\uddd0\uddde-\uddff\ude70-\ude74\ude78-\ude7a\ude80-\ude86\ude90-\udea8\udeb0-\udeb6\udec0-\udec2\uded0-\uded6]|[\u23e9-\u23ec\u23f0\u23f3\u267e\u26ce\u2705\u2728\u274c\u274e\u2753-\u2755\u2795-\u2797\u27b0\u27bf\ue50a])|\ufe0f/g

// +++ WF: added 'var', removed comma
// avoid runtime RegExp creation for not so smart,
// not JIT based, and old browsers / engines
var UFE0Fg = /\uFE0F/g

// +++ WF: added 'var', removed comma
// avoid using a string literal like '\u200D' here because minifiers expand it inline
var U200D = String.fromCharCode(0x200D)

// +++ WF: unchanged
function replace(text, callback) {
  return String(text).replace(re, callback);
}

// +++ WF: unchanged
/**
 * Used to both remove the possible variant
 *  and to convert utf16 into code points.
 *  If there is a zero-width-joiner (U+200D), leave the variants in.
 * @param   string    the raw text of the emoji match
 * @return  string    the code point
 */
function grabTheRightIcon(rawText) {
  // if variant is present as \uFE0F
  return toCodePoint(rawText.indexOf(U200D) < 0 ?
    rawText.replace(UFE0Fg, '') :
    rawText
  );
}

// +++ WF: Removed extra attributes handling, and replaced injected HTML.
/**
 * String/HTML version of the same logic / parser:
 *  emojify a generic text placing images tags instead of surrogates pair.
 * @param   string    generic string with possibly some emoji in it
 * @param   Object    options  containing info about how to parse
 *
 *            .callback   Function  the callback to invoke per each found emoji.
 *            .base       string    the base url, by default twemoji.base
 *            .ext        string    the image extension, by default twemoji.ext
 *            .size       string    the assets size, by default twemoji.size
 *
 * @return  the string with <img tags> replacing all found and parsed emoji
 *
 */
function parseString(str, options) {
  var emojiCount = 0, plainCount = 0; // +++ WF: added
  var ret = replace(str, function (rawText) { // +++ WF: don't return immediately
    var
      ret = options.includePlain ? rawText : '',
      iconId = grabTheRightIcon(rawText),
      src = options.callback(iconId, options);
    if (iconId && src) {
      // recycle the match string replacing the emoji
      // with its image counter part
      // +++ WF: Replaced injected HTML code.
      ret = options.asMarkup ? '<img '.concat(
        'src="',
        src,
        '" align="middle" width="',
        options.size,
        '" height="',
        options.size,
        '"/>'
      ) : src;
      // +++ WF: Removed extra attributes handling
      emojiCount++; // +++ WF: added counting
    } else {
      emojiCount++; // +++ WF: count even if the system font is used
    }
    return ret;
  });
  plainCount = String(str).replace(re, '').length; // +++ WF: remove emojis
  return { 'emojiCount': emojiCount, 'plainCount': plainCount, 'text': ret }; // +++ WF: added
}

// +++ WF: unchanged
function toCodePoint(unicodeSurrogates, sep) {
  var
    r = [],
    c = 0,
    p = 0,
    i = 0;
  while (i < unicodeSurrogates.length) {
    c = unicodeSurrogates.charCodeAt(i++);
    if (p) {
      r.push((0x10000 + ((p - 0xD800) << 10) + (c - 0xDC00)).toString(16));
      p = 0;
    } else if (0xD800 <= c && c <= 0xDBFF) {
      p = c;
    } else {
      r.push(c.toString(16));
    }
  }
  return r.join(sep || '-');
}

function parseAsMarkup(what, size, style, noGrow, maxRasterSize) {
    return parse(what, size, style, noGrow, maxRasterSize, true, true)
}

function parseSingleUrl(what, size, style, noGrow, maxRasterSize) {
    return parse(what, size, style, noGrow, maxRasterSize, false, false)
}

// +++ WF: Adapted from the original parse(what, how) function.
function parse(what, size, style, noGrow, maxRasterSize, includePlain, asMarkup) {
  var settings = getParseSettings(style, size, maxRasterSize, noGrow)
  return parseString(what, {
    callback: function(icon, options) {
      if (settings.useSystem) return null
      else return ''.concat(settings.stylePath, '/', icon, '.', style.ext)
    },
    size: settings.effectiveSize,
    includePlain: (includePlain !== false),
    asMarkup: (asMarkup !== false)
  });
}
