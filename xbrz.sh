#!/usr/bin/env bash
# MIT License
#
# Copyright © 2020 Hugo Locurcio and contributors
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -euo pipefail
IFS=$'\n\t'
cd "$(dirname "${BASH_SOURCE[0]}")"

shopt -s globstar

print_header() {
  echo -e "\n\e[1m[*] $1\e[0m"
}

# Textures in `actors/` don't need to be seamless. No need to bother with alpha
# decomposition for them.
print_header "Extracting the alpha channel into a separate texture..."
parallel convert {} -alpha extract "PNG24:{.}.alpha.png" ::: "$PWD"/{levels,textures}/**/*.png

# This step removes the alpha channel, so we need to extract alpha before.
# Apply a black background to avoid brightening the texture when merging it back.
print_header "Tiling textures with a 3×3 pattern (for seamless upscaling)..."
parallel montage {} -background black +clone +clone +clone +clone +clone +clone +clone +clone -tile 3x3 -geometry +0+0 {} ::: "$PWD"/{levels,textures}/**/*.png

print_header "Upscaling using xBRZ 2×..."
parallel xbrzscale 2 {} {} ::: "$PWD"/**/*.png

print_header "Cropping final images to match the originals..."
parallel mogrify -gravity center -crop 33.333333x33.333333%+0+0 {} ::: "$PWD"/{levels,textures}/**/*.png

print_header "Recomposing the alpha channel in images with transparency..."
parallel convert "{= s/.alpha.png/.png/ =}" {} -alpha off -compose copy_opacity -composite "{= s/.alpha.png/.png/ =}" ::: "$PWD"/{levels,textures}/**/*.alpha.png

print_header "Removing temporary alpha channel textures..."
rm -f "$PWD"/{levels,textures}/**/*.alpha.png

print_header "Optimizing the resulting images losslessly..."
parallel oxipng --strip all ::: "$PWD"/**/*.png

print_header "Done."
