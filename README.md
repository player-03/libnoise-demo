# libnoise-demo
Demonstrative code for my [guide to threads in Lime](https://player03.com/openfl/threads-guide/), and for [libnoise](https://github.com/memilian/libnoise/).

The ["threads" branch](https://github.com/player-03/libnoise-demo/commits/threads) is carefully curated to show the development process. The first commit is a feature-complete but laggy app, and from there the commits follow along with the thread guide, showing the full changes required at each step, along with commit messages explaining why. *The threads branch is considered complete, and may only be updated alongside the guide.*

The main branch contains the latest version of the app, as featured in my [libnoise review](https://player03.com/haxelib/haxelib-review-libnoise/). This version of the app is better optimized, improving the experience but making the effects of threads less obvious. Pull requests may be submitted to this branch.

## Using the demo
This demo is controlled almost exclusively via dropdown menus. Move your mouse over the canvas, and a menu will appear at the top. Choose a pattern from there to fill the canvas. (This may take some time depending on the pattern.)

Near the bottom of the dropdown, you'll find three types of operator. Picking one of these will make room for that type of operator, splitting the canvas up so that you can see inputs and outputs side-by-side.

With the canvas split up like this, there's less room to see the output pattern. If you'd like to see one of the sections in full, hover over it and click the fullscreen button that appears.

## Building the demo
As of this writing, this app relies on multiple pending pull requests, and building it takes extra steps.

1. Install the demo: `git clone https://github.com/player-03/libnoise-demo.git`
2. Install libnoise: `haxelib install https://github.com/player-03/libnoise.git`
3. Make sure you've installed Lime from Git: `haxelib install https://github.com/native-toolkit/lime.git`
4. Pull the "single_threaded_async" branch:

   ```text
   git remote add player-03 https://github.com/player-03/lime.git
   git checkout -b single_threaded_async player-03/single_threaded_async
   ```

5. Make sure you've installed OpenFL from Git: `haxelib install https://github.com/openfl/openfl.git`
6. Pull the "web_workers" branch:

   ```text
   git remote add player-03 https://github.com/player-03/openfl.git
   git checkout -b web_workers player-03/web_workers
   ```

7. Install [FeathersUI](https://lib.haxe.org/p/feathersui) and [openfl-click-group](https://lib.haxe.org/p/openfl-click-group) normally.
8. Build and run the demo using `lime test <target>`.
