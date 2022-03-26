package com.player03.libnoisedemo;

import com.player03.libnoisedemo.PatternDropdown;
import libnoise.ModuleBase;
import lime.app.Event;
import lime.system.ThreadPool;
import lime.system.WorkOutput;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import openfl.utils.ByteArray;

class CanvasSection {
	private static var threadPool:ThreadPool;
	private static function initThreadPool():Void {
		if(threadPool == null) {
			threadPool = new ThreadPool(1, 1, SINGLE_THREADED, 3/4);
		}
	}
	
	public var canvas(default, set):BitmapData;
	
	/**
	 * The full area this section fills. May have zero width or height.
	 */
	public var area(default, null):IntRectangle;
	/**
	 * The portion of `area` dedicated to the output pattern. Shares an edge
	 * with `childArea`. May have zero width or height.
	 */
	public var workArea(default, null):IntRectangle;
	/**
	 * The portion of `area` dedicated to children (input patterns). Shares an
	 * edge with `workArea`. May have zero width or height.
	 */
	public var childArea(default, null):IntRectangle = new IntRectangle();
	
	public var fullscreen(default, set):Bool = false;
	
	public var pattern(default, set):Pattern = Pattern.chooseGenerator;
	public var customDescription:Null<String> = null;
	/**
	 * The most recently drawn module. If non-null, `refill()` will assume its
	 * work is already done. Automatically becomes null when `pattern` changes.
	 */
	private var module:Null<ModuleBase> = null;
	public var toolTip(default, null):Null<String> = null;
	/**
	 * Whether this section has a drawable pattern and all required inputs are
	 * available.
	 */
	public var readyToDraw(get, never):Bool;
	
	private var jobID:Null<Int> = null;
	
	public var childCount(get, never):Int;
	private var children:Array<CanvasSection> = [];
	
	public var parent(default, null):Null<CanvasSection> = null;
	
	public var saved(default, null):Null<SectionDescription> = null;
	
	/**
	 * Dispatched whenever this section finishes redrawing.
	 */
	public var onRedraw(default, null):Event<() -> Void> = new Event<() -> Void>();
	
	public function new(canvas:BitmapData, area:IntRectangle, ?parent:CanvasSection) {
		this.canvas = canvas;
		this.area = area;
		workArea = area.clone();
		this.parent = parent;
		
		initThreadPool();
		
		threadPool.onComplete.add(onWorkComplete);
		threadPool.onError.add(onWorkError);
	}
	
	private function resetPattern():Void {
		pattern = childCount < 1 ? Pattern.chooseGenerator : (childCount == 1 ? Pattern.chooseOperator : Pattern.chooseMultiOperator);
		module = null;
		saved = null;
		toolTip = null;
	}
	
	/**
	 * Draws the given pattern to this section of the canvas, updating parents
	 * based on the new input.
	 */
	public function fill(pattern:Pattern, ?skipDrawStep:Bool = false):Void {
		if(pattern == null || this.pattern == pattern) {
			return;
		}
		
		if(pattern.hasSpecialMeaning) {
			var module:ModuleBase = pattern.getModule();
			
			if(Std.isOfType(module, Subdivide)) {
				if(fullscreen) {
					subdivide((cast module:Subdivide).count, false);
					fullscreen = false;
				} else {
					subdivide((cast module:Subdivide).count);
				}
				return;
			}
		}
		
		this.pattern = pattern;
		
		refill(true, true, skipDrawStep);
	}
	
	private function refillAll():Void {
		if(parent != null) {
			parent.refillAll();
		} else {
			invalidateChildren();
			refill();
		}
	}
	
	private function invalidateChildren():Void {
		module = null;
		@:bypassAccessor fullscreen = false;
		for(child in children) {
			child.invalidateChildren();
		}
	}
	
	/**
	 * Refills this section as well as children and parents that need it.
	 */
	private function refill(?refillChildren:Bool = true, ?refillParents:Bool = true, ?skipDrawStep:Bool = false):Void {
		if(module != null) {
			if(refillParents && parent != null) {
				parent.refill(false, true, skipDrawStep || fullscreen);
			}
			return;
		}
		
		if(pattern.hasSpecialMeaning) {
			if(pattern.name == "Choose...") {
				resetPattern();
			} else if(pattern == Pattern.clear) {
				if(childCount == 1) {
					var temp:Pattern = children[0].pattern;
					clear();
					pattern = temp;
				} else {
					clear();
				}
				if(fullscreen) {
					fullscreen = false;
					return;
				}
			} else {
				return;
			}
		}
		
		if(pattern.inputsExpected > childCount) {
			resetPattern();
			return;
		}
		
		if(refillChildren) {
			for(child in children) {
				child.refill(true, false, skipDrawStep || fullscreen);
			}
		}
		
		for(child in children) {
			if(child.module == null) {
				resetPattern();
				return;
			}
		}
		
		switch(pattern.inputsExpected) {
			case 1:
				module = pattern.getModule(children[0].module);
			case 2:
				module = pattern.getModule(children[0].module, children[1].module);
			case 3:
				module = pattern.getModule(children[0].module, children[1].module, children[2].module);
			default:
				module = pattern.getModule();
		}
		
		saved = null;
		
		if(!skipDrawStep) {
			toolTip = "Working...";
			
			if(jobID != null) {
				threadPool.cancelJob(jobID);
			}
			
			if(fullscreen) {
				jobID = threadPool.run(generatePattern, { module: module, workArea: new IntRectangle(0, 0, canvas.width, canvas.height) });
			} else {
				jobID = threadPool.run(generatePattern, { module: module, workArea: workArea.clone() });
			}
		}
		
		if(parent != null && refillParents) {
			parent.module = null;
			parent.refill(false, true, skipDrawStep || fullscreen);
		}
	}
	
	/**
	 * Draws the active pattern to the canvas.
	 */
	private static function generatePattern(state: { module:ModuleBase, workArea:IntRectangle, ?y:Int, ?bytes:ByteArray }, output:WorkOutput):Void {
		var module:ModuleBase = state.module;
		var workArea:IntRectangle = state.workArea;
		if(module == null) {
			output.sendError("Not a valid pattern.");
			return;
		} else if(workArea.width <= 0 || workArea.height <= 0) {
			output.sendError("Canvas section is too small.");
			return;
		}
		
		var bytes:ByteArray = state.bytes;
		if(bytes == null) {
			//Allocate four bytes per pixel.
			state.bytes = bytes = new ByteArray(workArea.width * workArea.height);
			
			state.y = workArea.top;
		}
		
		var endY:Int = state.y + 5;
		if(endY > workArea.bottom) {
			endY = workArea.bottom;
		}
		
		//Run `getValue()` for every pixel.
		for(y in state.y...endY) {
			for(x in workArea.left...workArea.right) {
				//`getValue()` returns a value in the range [-1, 1], and we need
				//to convert to [0, 255].
				var value:Int = Std.int(128 + 128 * module.getValue(x, y, 0));
				
				if(value > 255) {
					value = 255;
				} else if(value < 0) {
					value = 0;
				}
				
				//Store it as a color.
				bytes.writeInt(value << 16 | value << 8 | value);
			}
		}
		
		state.y = endY;
		
		if(state.y >= workArea.bottom) {
			output.sendComplete(bytes, [bytes]);
		}
	}
	
	private function onWorkComplete(bytes:ByteArray):Void {
		if(threadPool.activeJob.id != jobID) {
			return;
		}
		
		if(!pattern.hasSpecialMeaning) {
			toolTip = "Calculation time: " + (Math.round(threadPool.activeJob.duration * 1000) / 1000) + "s";
		} else {
			toolTip = null;
		}
		
		//Draw the pixels to the canvas.
		bytes.position = 0;
		canvas.setPixels(fullscreen ? new Rectangle(0, 0, canvas.width, canvas.height) : workArea.toFloatRectangle(), bytes);
		bytes.clear();
		
		onRedraw.dispatch();
		
		jobID = null;
	}
	
	private function onWorkError(error:String):Void {
		if(threadPool.activeJob.id != jobID) {
			return;
		}
		
		toolTip = error;
		
		jobID = null;
	}
	
	/**
	 * Clears the section, but doesn't immediately refill.
	 */
	public function clear():Void {
		for(child in children) {
			child.clear();
			
			threadPool.onComplete.remove(child.onWorkComplete);
			threadPool.onError.remove(child.onWorkError);
		}
		
		children.resize(0);
		
		pattern = Pattern.chooseGenerator;
		saved = null;
		toolTip = null;
		workArea.copyFrom(area);
		childArea.width = 0;
		childArea.height = 0;
	}
	
	/**
	 * Splits up this section into smaller sections, leaving an area for an
	 * operator's output.
	 */
	public function subdivide(count:Int, ?refill:Bool = true) {
		if(count < 1 || count > 3) {
			return;
		}
		
		var grandchildren:Array<CanvasSection> = null;
		if(children.length > 0) {
			grandchildren = children;
			children = [];
		}
		
		if(pattern.hasSpecialMeaning) {
			resetPattern();
		}
		
		for(i in 0...count) {
			var child:CanvasSection = new CanvasSection(canvas, area.clone(), this);
			child.pattern = pattern;
			child.module = module;
			child.toolTip = toolTip;
			children.push(child);
		}
		
		if(grandchildren != null) {
			for(grandchild in grandchildren) {
				grandchild.parent = children[0];
			}
			children[0].children = grandchildren;
			
			if(pattern.inputsExpected > 0) {
				//Don't duplicate any pattern with inputs.
				for(i in 1...count) {
					children[i].resetPattern();
				}
			}
		}
		
		resetPattern();
		recalculateArea();
		if(refill) {
			this.refill();
		}
	}
	
	private function recalculateArea():Void {
		workArea.copyFrom(area);
		if(childCount < 1) {
			return;
		}
		
		childArea.copyFrom(area);
		
		var horizontalCount:Int = 1;
		var verticalCount:Int = 1;
		
		var horizontalChildren:Bool = area.width > area.height;
		if(childCount == 1) {
			horizontalChildren = !horizontalChildren;
		}
		
		if(horizontalChildren) {
			workArea.height = Math.round(workArea.height * 0.333);
			
			childArea.y = workArea.bottom;
			childArea.height = area.height - workArea.height;
			
			horizontalCount = childCount;
		} else {
			workArea.width = Math.round(workArea.width * 0.333);
			
			childArea.x = workArea.right;
			childArea.width = area.width - workArea.width;
			
			verticalCount = childCount;
		}
		
		var width:Int = Std.int(childArea.width / horizontalCount);
		var height:Int = Std.int(childArea.height / verticalCount);
		var index:Int = 0;
		var newArea:IntRectangle = new IntRectangle();
		for(x in 0...horizontalCount) {
			for(y in 0...verticalCount) {
				newArea.setTo(childArea.x + width * x, childArea.y + height * y, width, height);
				
				if(!children[index].area.equals(newArea)) {
					//If the new area isn't within the old, it's safe to assume
					//the section should be redrawn. Sections with children may
					//need to be redrawn too, and it's hard to tell, so err on
					//the side of caution.
					if(children[index].childCount > 0 || !children[index].area.containsRect(newArea)) {
						children[index].module = null;
					}
					
					children[index].area.copyFrom(newArea);
					children[index].recalculateArea();
				}
				
				index++;
				
				if(index >= children.length) {
					return;
				}
			}
		}
	}
	
	public function getSubsection(x:Int, y:Int):CanvasSection {
		if(fullscreen) {
			return this;
		}
		
		var result:CanvasSection = EmptyCanvasSection.instance;
		for(child in children) {
			var possibleResult:CanvasSection = child.getSubsection(x, y);
			if(possibleResult != EmptyCanvasSection.instance) {
				result = possibleResult;
				if(result.fullscreen) {
					return result;
				}
			}
		}
		
		if(workArea != null && workArea.contains(x, y) && readyToDraw) {
			return this;
		}
		
		return result;
	}
	
	public inline function getSubsectionArea(index:Int):IntRectangle {
		return children[index].workArea;
	}
	
	public function save():SectionDescription {
		if(saved == null) {
			if(childCount > 0) {
				saved = {
					pattern: pattern.name,
					inputs: [for(child in children) child.save()]
				};
			} else {
				saved = {
					pattern: pattern.name
				};
			}
		}
		
		return saved;
	}
	
	public function load(description:SectionDescription, getPattern:(Int, String) -> Null<Pattern>, ?fullscreen:Bool = false, ?skipDrawStep:Bool = false):Void {
		clear();
		
		@:bypassAccessor this.fullscreen = fullscreen;
		
		customDescription = description.description;
		
		var inputs:Int = 0;
		if(description.inputs != null) {
			inputs = description.inputs.length;
			subdivide(inputs, false);
			for(i in 0...childCount) {
				children[i].load(description.inputs[i], getPattern, false, skipDrawStep || fullscreen);
			}
		}
		
		fill(getPattern(inputs, description.pattern), skipDrawStep);
	}
	
	private function set_canvas(value:BitmapData):BitmapData {
		for(child in children) {
			child.canvas = value;
		}
		module = null;
		return canvas = value;
	}
	
	private inline function get_childCount():Int {
		return children.length;
	}
	
	private inline function get_workArea():IntRectangle {
		return workArea != null ? workArea : area;
	}
	
	private function get_readyToDraw():Bool {
		if(canvas == null) {
			return false;
		}
		
		for(child in children) {
			if(child.pattern.hasSpecialMeaning || child.module == null) {
				return false;
			}
		}
		
		return true;
	}
	
	private function set_pattern(value:Pattern):Pattern {
		if(pattern != value) {
			module = null;
		}
		return pattern = value;
	}
	
	private function set_fullscreen(value:Bool):Bool {
		if(canvas == null) {
			return fullscreen = false;
		}
		
		if(fullscreen != value) {
			fullscreen = value;
			
			if(fullscreen) {
				module = null;
				refill(false, false);
			} else {
				refillAll();
			}
		}
		
		return fullscreen;
	}
}

private class EmptyCanvasSection extends CanvasSection {
	public static var instance(get, null):EmptyCanvasSection;
	private static function get_instance():EmptyCanvasSection {
		if(instance == null) {
			instance = new EmptyCanvasSection();
		}
		return instance;
	}
	
	private function new() {
		super(null, new IntRectangle(-1000, -1000));
	}
	
	public override function fill(pattern:Pattern, ?skipDrawStep:Bool = false):Void {}
	public override function subdivide(count:Int, ?refill:Bool = false) {}
	public override function getSubsection(x:Float, y:Float):CanvasSection {
		return this;
	}
	public override function save():SectionDescription {
		return { pattern: "Empty" };
	}
	public override function load(description:SectionDescription, getPattern:(Int, String) -> Null<Pattern>, ?fullscreen:Bool = false, ?skipDrawStep:Bool = false) {}
}

class RootCanvasSection extends CanvasSection {
	private var bitmap:Bitmap;
	
	public function new(bitmap:Bitmap, width:Int, height:Int) {
		this.bitmap = bitmap;
		super(null, new IntRectangle());
		resize(width, height, false);
	}
	
	public function resize(width:Int, height:Int, ?refill:Bool = true):Void {
		if(area.width == width && area.height == height) {
			return;
		}
		
		if(canvas != null) {
			canvas.dispose();
		}
		
		area.width = width;
		area.height = height;
		canvas = new BitmapData(width, height, false, 0x000000);
		bitmap.bitmapData = canvas;
		
		recalculateArea();
		if(refill) {
			this.refill();
		}
	}
}

typedef SectionDescription = {
	@:optional var description:String;
	var pattern:String;
	@:optional var inputs:Array<SectionDescription>;
};
