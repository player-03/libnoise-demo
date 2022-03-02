# libnoise-demo
Demonstrative code for my [guide to threads in Lime](https://player03.com/openfl/threads-guide/), and for [libnoise](https://github.com/memilian/libnoise/).

The ["threads" branch](https://github.com/player-03/libnoise-demo/commits/threads) is carefully curated to show the development process. The first commit is a feature-complete but laggy app, and from there the commits follow along with the thread guide, showing the full changes required at each step, along with commit messages explaining why. *The threads branch is considered complete, and may only be updated alongside the guide.*

The main branch contains the latest version of the app, as featured in my [libnoise review](https://player03.com/haxelib/haxelib-review-libnoise/). This version of the app is better optimized, improving the experience but making the effects of threads less obvious. Pull requests may be submitted to this branch.

## Using the demo
This demo is controlled almost exclusively via dropdown menus. Move your mouse over the canvas, and a menu will appear at the top. Choose a pattern from there to fill the canvas. (This may take some time depending on the pattern.)

Near the bottom of the dropdown, you'll find three types of operator. Picking one of these will make room for that type of operator, splitting the canvas up so that you can see inputs and outputs side-by-side.

With the canvas split up like this, there's less room to see the output pattern. If you'd like to see one of the sections in full, hover over it and click the fullscreen button that appears.
