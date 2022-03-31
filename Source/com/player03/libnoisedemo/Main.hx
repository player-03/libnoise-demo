package com.player03.libnoisedemo;

import com.player03.libnoisedemo.CanvasSection;
import feathers.controls.Button;
import feathers.controls.LayoutGroup;
import feathers.controls.TextArea;
import feathers.controls.TextCallout;
import feathers.core.DefaultToolTipManager;
import feathers.core.ToolTipManager;
import feathers.layout.AnchorLayout;
import feathers.layout.AnchorLayoutData;
import haxe.Json;
import openfl.Assets;
import openfl.display.Bitmap;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.events.TouchEvent;
import openfl.Lib;
import openfl.ui.Keyboard;

using StringTools;

@:expose("LibnoiseDemo")
@:allow(com.player03.libnoisedemo.Main)
class MainAPI {
	private static var main:Main;
	
	public static function loadPattern(pattern:String, ?fullscreen:Bool):Void {
		if(main == null) {
			return;
		}
		
		if(fullscreen != null) {
			main.ui.toggleFullscreenProhibited = fullscreen && main.ui.editingProhibited;
		}
		
		main.load(main.canvasRoot, pattern, fullscreen);
	}
	public static var onPatternChange(default, null) = new lime.app.Event<String -> Void>();
	
	public static function setEditingProhibited(prohibited:Bool):Void {
		if(main == null) {
			return;
		}
		
		main.ui.editingProhibited = prohibited;
		main.ui.refreshSection();
		
		if(!prohibited) {
			main.removeEventListener(MouseEvent.CLICK, main.cycleThroughSamples);
			main.removeEventListener(MouseEvent.RIGHT_MOUSE_DOWN, main.cycleThroughSamples);
		}
	}
	
	public static function enableGalleryMode(?fullscreen:Bool = true):Void {
		if(main == null) {
			return;
		}
		
		main.ui.editingProhibited = true;
		main.ui.toggleFullscreenProhibited = fullscreen;
		main.fullscreenSamples = fullscreen;
		main.canvasRoot.clear();
		main.canvasRoot.customDescription = "Click to begin";
		main.refreshSelection();
		main.ui.header.toolTip = null;
		main.addEventListener(MouseEvent.CLICK, main.cycleThroughSamples);
		main.addEventListener(MouseEvent.RIGHT_MOUSE_DOWN, main.cycleThroughSamples);
	}
	
	public static function resizeCanvas():Void {
		if(main == null) {
			return;
		}
		
		main.resizeCanvas(null);
	}
	
	public static function refreshToolTip():Void {
		if(main == null) {
			return;
		}
		
		main.toolTips.refreshToolTip();
	}
}

@:allow(com.player03.libnoisedemo.MainAPI)
class Main extends LayoutGroup {
	private var toolTips:CustomToolTipManager;
	
	private var resizeCanvasButton:Button;
	
	private var canvas:Bitmap;
	private var canvasRoot:RootCanvasSection;
	private var ui:SectionUI;
	
	private var textInput:TextArea;
	private var lastSavedSection:CanvasSection = null;
	private var ignoreEvents:Bool = false;
	
	private var samples:Array<SectionDescription>;
	private var sampleIndex:Int = -1;
	private var preventSampleChange:Bool = false;
	private var fullscreenSamples:Bool = true;
	
	public function new() {
		super();
		
		MainAPI.main = this;
		
		layout = new AnchorLayout();
		
		resizeCanvasButton = new Button();
		resizeCanvasButton.icon = new Bitmap(Assets.getBitmapData("assets/Refresh.png"));
		resizeCanvasButton.layoutData = AnchorLayoutData.center();
		resizeCanvasButton.visible = false;
		stage.addEventListener(Event.RESIZE, checkResizeNeeded);
		resizeCanvasButton.addEventListener(MouseEvent.CLICK, resizeCanvas);
		addChild(resizeCanvasButton);
		
		canvas = new Bitmap();
		addChild(canvas);
		canvasRoot = new RootCanvasSection(canvas, stage.stageWidth, stage.stageHeight);
		canvasRoot.onRedraw.add(onRootRedraw);
		
		ToolTipManager.toolTipManagerFactory = CustomToolTipManager.new;
		toolTips = cast(ToolTipManager.addRoot(stage), CustomToolTipManager);
		
		PatternDropdown.cache(0, 0, 0, canvas.bitmapData.width, canvas.bitmapData.height, 0);
		
		ui = new SectionUI();
		addChild(ui);
		
		ui.section = canvasRoot;
		
		textInput = new TextArea();
		textInput.y = -50;
		textInput.maxHeight = 40;
		textInput.addEventListener(Event.CHANGE, onTextChange);
		addChild(textInput);
		
		samples = Json.parse(Assets.getText("assets/Samples.json"));
		
		#if libnoise_demo_gallery_mode
		MainAPI.enableGalleryMode();
		#elseif html5
		if(js.Browser.location.hash == "#gallery-mode") {
			MainAPI.enableGalleryMode();
		} else if(js.Browser.location.hash == "#start-simple") {
			ui.editingProhibited = true;
			ui.toggleFullscreenProhibited = true;
			load(canvasRoot, "Perlin (4)");
			ui.section = null;
		}
		#end
		
		addEventListener(TouchEvent.TOUCH_BEGIN, onTouch);
		addEventListener(TouchEvent.TOUCH_MOVE, onTouch);
		addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
		stage.addEventListener(Event.MOUSE_LEAVE, onMouseLeave);
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
	}
	
	private function refreshSelection():Void {
		if(ui.section != null && !selectSectionAt(mouseX, mouseY)) {
			ui.refreshSection();
			toolTips.refreshToolTip();
		}
	}
	
	/**
	 * @return Whether the section changed.
	 */
	private function selectSectionAt(x:Float, y:Float):Bool {
		if(canvas.visible && !ui.dropdown.open) {
			var newSection:CanvasSection = canvasRoot.getSubsection(Math.round(x), Math.round(y));
			if(ui.section != newSection) {
				ui.section = newSection;
				toolTips.hideToolTip();
				return true;
			}
		}
		
		return false;
	}
	
	private function onTouch(e:TouchEvent):Void {
		if(selectSectionAt(e.stageX, e.stageY) && e.type == TouchEvent.TOUCH_MOVE) {
			preventSampleChange = true;
		}
	}
	
	private function onMouseMove(e:MouseEvent):Void {
		if(!e.buttonDown) {
			selectSectionAt(e.stageX, e.stageY);
		}
	}
	
	private function onMouseLeave(e:Event):Void {
		ui.section = null;
		toolTips.hideToolTip();
	}
	
	private function onKeyDown(e:KeyboardEvent):Void {
		if(e.keyCode == Keyboard.CONTROL || e.keyCode == Keyboard.COMMAND) {
			if(stage.focus != textInput && !ui.dropdown.open) {
				stage.focus = textInput;
				textInput.selectAll();
			}
			
			if(ui.section == null) {
				ignoreEvents = true;
				textInput.text = "";
				ignoreEvents = false;
			} else if(ui.section.saved == null || ui.section != lastSavedSection) {
				ignoreEvents = true;
				textInput.text = Json.stringify(ui.section.save());
				textInput.selectAll();
				ignoreEvents = false;
				
				lastSavedSection = ui.section;
			}
		} else if(e.ctrlKey && e.keyCode == Keyboard.C && ui.section != null) {
			if(ui.section == canvasRoot) {
				TextCallout.show("Copied the canvas.", ui.dropdown);
			} else {
				TextCallout.show("Copied this section.", ui.dropdown);
			}
		}
	}
	
	private function onRootRedraw():Void {
		if(!canvasRoot.pattern.hasSpecialMeaning) {
			MainAPI.onPatternChange.dispatch(Json.stringify(canvasRoot.save()));
		}
	}
	
	private function onTextChange(e:Event):Void {
		if(ignoreEvents || ui.editingProhibited) {
			return;
		}
		
		var text:String = textInput.text;
		if(text.startsWith("{")) {
			text = text.replace("“", '"').replace("”", '"');
		}
		
		load(ui.section != null ? ui.section : canvasRoot, text);
	}
	
	private function checkResizeNeeded(e:Event):Void {
		explicitWidth = stage.stageWidth;
		explicitHeight = stage.stageHeight;
		
		var resizeNeeded:Bool = canvasRoot.area.width != stage.stageWidth || canvasRoot.area.height != stage.stageHeight;
		if(resizeNeeded != resizeCanvasButton.visible) {
			resizeCanvasButton.visible = resizeNeeded;
			canvas.visible = !resizeNeeded;
			
			if(resizeNeeded) {
				ui.section = null;
			} else if(ui.section != null) {
				refreshSelection();
			}
		}
	}
	
	private function resizeCanvas(e:MouseEvent):Void {
		canvasRoot.resize(stage.stageWidth, stage.stageHeight);
		checkResizeNeeded(null);
		e.stopPropagation();
	}
	
	private function load(section:CanvasSection, text:String, ?fullscreen:Bool):Void {
		if(fullscreen == null) {
			fullscreen = section.fullscreen;
		}
		
		if(StringTools.startsWith(text, "{")) {
			try {
				section.load(Json.parse(text), ui.getPattern, fullscreen);
				
				refreshSelection();
			} catch(e) {}
		} else {
			for(sample in samples) {
				if(sample.description == text) {
					section.load(sample, ui.getPattern, fullscreen);
					return;
				}
			}
			
			section.load({pattern: text}, ui.getPattern, fullscreen);
			
			refreshSelection();
		}
	}
	
	private function cycleThroughSamples(e:MouseEvent):Void {
		if(preventSampleChange || resizeCanvasButton.visible) {
			preventSampleChange = false;
			return;
		}
		
		if(e.type.indexOf("right") >= 0) {
			sampleIndex--;
			if(sampleIndex < 0) {
				sampleIndex = samples.length - 1;
			}
		} else {
			sampleIndex++;
			if(sampleIndex >= samples.length) {
				sampleIndex = 0;
			}
		}
		
		canvasRoot.load(samples[sampleIndex], ui.getPattern, fullscreenSamples);
		
		refreshSelection();
	}
}

private class CustomToolTipManager extends DefaultToolTipManager {
	private static inline var Y_OFFSET:Float = 20;
	
	private var mouseMoveTime:Int = -1;
	
	public override function hideToolTip() {
		super.hideToolTip();
		_hideTime = -1;
	}
	
	public function refreshToolTip():Void {
		if(_toolTip == null || _toolTip.stage == null) {
			return;
		}
		
		if(_target == null || _target.toolTip == null) {
			hideToolTip();
			return;
		}
		
		_toolTip.text = _target.toolTip;
	}
	
	private override function hoverDelayCallback():Void {
		if(Lib.getTimer() - mouseMoveTime < 200) {
			this._delayTimeoutID = Lib.setTimeout(hoverDelayCallback, Std.int(this._delay * 1000.0));
			return;
		}
		
		super.hoverDelayCallback();
		
		if(_toolTip != null && _toolTipStageY + Y_OFFSET + _toolTip.height <= _target.stage.stageHeight) {
			_toolTip.y = _toolTipStageY + Y_OFFSET;
		}
	}
	
	private override function defaultToolTipManager_root_mouseMoveHandler(event:MouseEvent):Void {
		mouseMoveTime = Lib.getTimer();
		
		if(_toolTip != null) {
			if(_toolTip.stage != null) {
				super.hideToolTip();
			} else if(_delayTimeoutID == null && mouseMoveTime - _hideTime > 400) {
				clearTarget();
			}
		}
		
		super.defaultToolTipManager_root_mouseMoveHandler(event);
	}
	
	private override function defaultToolTipManager_target_mouseDownHandler(event:MouseEvent):Void {
		//Ignore.
	}
	private override function defaultToolTipManager_target_rightMouseDownHandler(event:MouseEvent):Void {
		//Ignore.
	}
}
