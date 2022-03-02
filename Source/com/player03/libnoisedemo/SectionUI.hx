package com.player03.libnoisedemo;

import com.player03.libnoisedemo.Main.MainAPI;
import com.player03.libnoisedemo.CanvasSection;
import feathers.controls.Button;
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.layout.AnchorLayout;
import feathers.layout.AnchorLayoutData;
import feathers.skins.RectangleSkin;
import openfl.display.Bitmap;
import openfl.display.Graphics;
import openfl.display.Shape;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.utils.Assets;

class SectionUI extends LayoutGroup {
	private static inline var MARGIN:Int = 5;
	
	public var section(default, set):Null<CanvasSection> = null;
	
	private var lines:Shape;
	
	public var header(default, null):Label;
	
	private var fullscreenButton:Button;
	private var fullscreenIcon:Bitmap;
	private var exitFullscreenIcon:Bitmap;
	
	private var dropdownsWithSubdivide:Array<PatternDropdown>;
	private var dropdownsWithoutSubdivide:Array<PatternDropdown>;
	public var dropdown(default, set):PatternDropdown;
	
	public var editingProhibited(default, set):Bool = false;
	public var toggleFullscreenProhibited(default, set):Bool = false;
	
	public function new() {
		super();
		layout = new AnchorLayout();
		
		visible = false;
		
		lines = new Shape();
		addChild(lines);
		
		var topCenter:AnchorLayoutData = AnchorLayoutData.topCenter(MARGIN);
		
		header = new Label();
		header.backgroundSkin = new RectangleSkin(SolidColor(0xFFFFFF));
		header.layoutData = topCenter;
		header.variant = Label.VARIANT_HEADING;
		header.visible = false;
		addChild(header);
		
		dropdownsWithSubdivide = PatternDropdown.getDropdowns(true);
		dropdownsWithoutSubdivide = PatternDropdown.getDropdowns(false);
		for(dropdown in dropdownsWithSubdivide.concat(dropdownsWithoutSubdivide)) {
			dropdown.layoutData = topCenter;
			dropdown.visible = false;
			dropdown.addEventListener(Event.CHANGE, onPatternChange);
			addChild(dropdown);
		}
		
		dropdown = dropdownsWithoutSubdivide[0];
		dropdown.validateNow();
		
		fullscreenIcon = new Bitmap(Assets.getBitmapData("assets/Fullscreen.png"));
		exitFullscreenIcon = new Bitmap(Assets.getBitmapData("assets/ExitFullscreen.png"));
		fullscreenButton = new Button();
		fullscreenButton.icon = fullscreenIcon;
		fullscreenButton.addEventListener(MouseEvent.CLICK, toggleFullscreen);
		addChild(fullscreenButton);
	}
	
	private function onPatternChange(e:Event):Void {
		if(section != null) {
			if(dropdown.selectedItem == null) {
				return;
			}
			section.fill(dropdown.selectedItem);
			
			toolTip = section.toolTip;
		}
	}
	
	private function toggleFullscreen(e:MouseEvent):Void {
		if(section != null) {
			section.fullscreen = !section.fullscreen;
			refreshSection();
		}
	}
	
	public function getPattern(inputs:Int, name:String):Null<Pattern> {
		return dropdownsWithSubdivide[inputs].getPatternByName(name);
	}
	
	private function set_section(value:Null<CanvasSection>):Null<CanvasSection> {
		if(value == section || dropdown.open) {
			return section;
		}
		
		if(section != null) {
			section.onRedraw.remove(refreshSection);
		}
		
		section = value;
		
		if(section != null) {
			section.onRedraw.add(refreshSection);
		}
		
		refreshSection();
		
		return section;
	}
	
	public function refreshSection():Void {
		if(section == null || stage == null || !section.readyToDraw) {
			visible = false;
		} else {
			visible = true;
			
			if(section.fullscreen) {
				x = 0;
				y = 0;
				explicitWidth = section.canvas.width;
				explicitHeight = section.canvas.height;
			} else {
				var area:IntRectangle = section.workArea;
				x = area.x;
				y = area.y;
				explicitWidth = area.width;
				explicitHeight = area.height;
			}
			
			lines.x = -x;
			lines.y = -y;
			lines.graphics.clear();
			lines.graphics.lineStyle(2, 0x00CCCC);
			lines.graphics.beginFill(0, 0);
			lines.graphics.drawRect(x + 1, y + 1, explicitWidth - 2, explicitHeight - 2);
			lines.graphics.endFill();
			
			if(!section.fullscreen) {
				for(i in 0...section.childCount) {
					var subArea:IntRectangle = section.getSubsectionArea(i);
					
					lines.graphics.lineStyle(2, 0x00CCCC, 0.5);
					lines.graphics.drawRect(subArea.x + 1, subArea.y + 1, subArea.width - 2, subArea.height - 2);
					
					Arrow.drawArrowBetweenAreas(lines.graphics, subArea, section.workArea);
				}
				
				if(section.parent != null) {
					Arrow.drawArrowBetweenAreas(lines.graphics, section.workArea, section.parent.workArea, true);
				}
			}
			
			var dropdowns:Array<PatternDropdown>;
			if(section.area.height < 150) {
				dropdowns = dropdownsWithoutSubdivide;
			} else {
				dropdowns = dropdownsWithSubdivide;
			}
			
			dropdown = dropdowns[section.childCount];
			dropdown.selectedItem = section.pattern;
			
			header.visible = editingProhibited;
			if(section.customDescription != null) {
				header.text = section.customDescription;
			} else if(!section.pattern.hasSpecialMeaning) {
				header.text = section.pattern.name;
			} else {
				header.visible = false;
			}
			
			dropdown.toolTip = section.pattern.description;
			if(!section.pattern.hasSpecialMeaning && (!section.fullscreen || !toggleFullscreenProhibited)) {
				header.toolTip = section.pattern.description;
			}
			toolTip = section.toolTip;
			MainAPI.refreshToolTip();
			
			if(toggleFullscreenProhibited) {
				fullscreenButton.visible = false;
			} else if(section.fullscreen) {
				fullscreenButton.visible = true;
				
				fullscreenButton.icon = exitFullscreenIcon;
				fullscreenButton.x = section.workArea.right - fullscreenButton.width - MARGIN;
				fullscreenButton.y = section.workArea.bottom - fullscreenButton.height - MARGIN;
			} else {
				fullscreenButton.visible = !section.pattern.hasSpecialMeaning
					&& (section.parent != null || section.childCount > 0);
				
				fullscreenButton.icon = fullscreenIcon;
				fullscreenButton.x = explicitWidth - fullscreenButton.width - MARGIN;
				fullscreenButton.y = explicitHeight - fullscreenButton.height - MARGIN;
			}
		}
	}
	
	private function set_editingProhibited(value:Bool):Bool {
		editingProhibited = value;
		
		if(!editingProhibited) {
			toggleFullscreenProhibited = false;
		}
		
		header.visible = editingProhibited;
		set_dropdown(dropdown);
		
		return editingProhibited;
	}
	
	private function set_toggleFullscreenProhibited(value:Bool):Bool {
		if(value) {
			fullscreenButton.visible = false;
		}
		
		return toggleFullscreenProhibited = value;
	}
	
	private function set_dropdown(value:PatternDropdown):PatternDropdown {
		if(value == null || value.parent != this) {
			return dropdown;
		}
		
		if(dropdown != null) {
			dropdown.closeListView();
			dropdown.visible = false;
			stage.focus = stage;
		}
		
		dropdown = value;
		
		if(!editingProhibited && section != null) {
			dropdown.visible = true;
		}
		
		return dropdown;
	}
}

class Arrow {
	private static inline function clamp(input:Float, min:Float, max:Float):Float {
		return input < min ? min : (input > max ? max : input);
	}
	
	public static function drawArrowBetweenAreas(graphics:Graphics, from:IntRectangle, to:IntRectangle, ?exiting:Bool = false):Void {
		var fromX:Float = from.x + from.width / 2;
		var fromY:Float = from.y + from.height / 2;
		var toX:Float = clamp(fromX, to.left - 1, to.right + 1);
		var toY:Float = clamp(fromY, to.top - 1, to.bottom + 1);
		
		if(exiting) {
			var deltaX:Float = clamp(toX - fromX, -to.width / 2, to.width / 2);
			var deltaY:Float = clamp(toY - fromY, -to.height / 2, to.height / 2);
			
			fromX = toX;
			fromY = toY;
			toX = fromX + deltaX;
			toY = fromY + deltaY;
		}
		
		drawArrow(graphics, fromX, fromY, toX, toY);
	}
	
	public static function drawArrow(graphics:Graphics, fromX:Float, fromY:Float, toX:Float, toY:Float):Void {
		var length:Float = Math.sqrt((toX - fromX) * (toX - fromX) + (toY - fromY) * (toY - fromY));
		if(length < 20) {
			return;
		}
		
		graphics.beginFill(0x00CCCC);
		graphics.lineStyle(3 + 0.01 * length, 0x00CCCC, 1, false, NONE, ROUND, ROUND);
		graphics.moveTo(fromX, fromY);
		graphics.lineTo(toX, toY);
		
		var angle:Float = Math.atan2(fromY - toY, fromX - toX);
		var angleOffset:Float = 0.4;
		var arrowheadSize:Float = 10 + 0.04 * length;
		graphics.lineTo(toX + arrowheadSize * Math.cos(angle + angleOffset),
			toY + arrowheadSize * Math.sin(angle + angleOffset));
		graphics.lineTo(toX + arrowheadSize * 0.7 * Math.cos(angle),
			toY + arrowheadSize * 0.7 * Math.sin(angle));
		graphics.lineTo(toX + arrowheadSize * Math.cos(angle - angleOffset),
			toY + arrowheadSize * Math.sin(angle - angleOffset));
		graphics.lineTo(toX, toY);
		
		graphics.endFill();
	}
}
