package com.player03.libnoisedemo;

import com.player03.clickgroup.ClickGroup;
import com.player03.libnoisedemo.operation.Average;
import feathers.controls.Button;
import feathers.controls.ListView;
import feathers.controls.PopUpListView;
import feathers.controls.ToggleButton;
import feathers.core.ITextControl;
import feathers.data.ArrayCollection;
import feathers.data.ListViewItemState;
import feathers.utils.DisplayObjectFactory;
import haxe.xml.Access;
import libnoise.generator.*;
import libnoise.ModuleBase;
import libnoise.operation.*;
import libnoise.QualityMode;
import openfl.events.MouseEvent;
import openfl.utils.Assets;

using StringTools;

class PatternDropdown extends PopUpListView {
	private static var descriptions(get, null):Map<String, String>;
	private static function get_descriptions():Map<String, String> {
		if(descriptions == null) {
			descriptions = new Map();
			var descriptionXML:Access = new Access(Xml.parse(Assets.getText("assets/Descriptions.html")));
			for(dl in descriptionXML.node.html.node.body.nodes.dl) {
				var dt:Array<Access> = [];
				var saved:Bool = false;
				for(node in dl.elements) {
					switch(node.name) {
						case "dt":
							if(saved) {
								dt = [];
								saved = false;
							}
							
							dt.push(node);
						case "dd":
							var description:String = ~/[\r\n\t]+/g.replace(node.innerHTML, "")
								.replace("<br/>", "\n")
								.htmlUnescape();
							
							for(dtNode in dt) {
								descriptions[dtNode.innerData] = description;
							}
							
							saved = true;
						default:
					}
				}
			}
		}
		
		return descriptions;
	}
	
	private static var patterns(get, null):Array<Array<Pattern>> = null;
	private static function get_patterns():Array<Array<Pattern>> {
		if(patterns == null) {
			var frequency:Float = 0.01;
			var lacunarity:Float = 2;
			var persistence:Float = 0.5;
			var seed:Int = Std.int(Math.random() * 0x7FFFFFFF);
			var quality:QualityMode = HIGH;
			#if html5
			//Enum values contain a field that can't be passed to web workers.
			Reflect.deleteField(quality, "toString");
			#end
			
			patterns = [
				//Zero inputs.
				[
					(new Const(-1):Pattern).withName("Const (black)"),
					(new Const(0):Pattern).withName("Const (gray)"),
					(new Const(1):Pattern).withName("Const (white)"),
					new Sphere(frequency),
					new Cylinder(frequency),
					new Checker(),
					(new Perlin(frequency, lacunarity, persistence, 2, seed, quality):Pattern).withName("Perlin (2)"),
					(new Perlin(frequency, lacunarity, persistence, 4, seed, quality):Pattern).withName("Perlin (4)"),
					(new Perlin(frequency, lacunarity, persistence, 8, seed, quality):Pattern).withName("Perlin (8)"),
					(new RidgedMultifractal(frequency, lacunarity, 2, seed, quality):Pattern).withName("RidgedMultifractal (2)"),
					(new RidgedMultifractal(frequency, lacunarity, 4, seed, quality):Pattern).withName("RidgedMultifractal (4)"),
					(new RidgedMultifractal(frequency, lacunarity, 8, seed, quality):Pattern).withName("RidgedMultifractal (8)"),
					(new Billow(frequency, lacunarity, persistence, 2, seed, quality):Pattern).withName("Billow (2)"),
					(new Billow(frequency, lacunarity, persistence, 4, seed, quality):Pattern).withName("Billow (4)"),
					(new Billow(frequency, lacunarity, persistence, 8, seed, quality):Pattern).withName("Billow (8)"),
					//In HTML5, Voronoi diagrams break if the seed gets too big,
					//likely because integers aren't capped, and the algorithm
					//assumes they are.
					new Voronoi(frequency * 2, 1, seed & 0x3FF, false),
					(new Voronoi(frequency * 2, 1, seed & 0x3FF, true):Pattern).withName("Voronoi (show seeds)")
				],
				//One input.
				[
					Abs.new,
					Clamp.new.bind(-0.5, 0.5),
					Invert.new,
					Rotate.new.bind(0, 0, 10),
					(Rotate.new.bind(10, 0, 0):Pattern).withName("Rotate (3D)"),
					(Scale.new.bind(2/3, 2/3, 2/3):Pattern).withName("Scale up"),
					(Scale.new.bind(3/2, 3/2, 3/2):Pattern).withName("Scale down"),
					Translate.new.bind(30, 30, 0),
					(Translate.new.bind(0, 0, 60):Pattern).withName("Translate (3D)"),
					(Turbulence.new.bind(4, _, null, null, null):Pattern).withName("Turbulence (low)"),
					(Turbulence.new.bind(10, _, null, null, null):Pattern).withName("Turbulence (high)")
				],
				//Two inputs.
				[
					Add.new,
					Average.new,
					Subtract.new,
					Multiply.new,
					Min.new,
					Max.new
				],
				//Three inputs.
				[
					//1000 isn't important, it just needs to be out of range.
					Select.new.bind(0, 1000, 0),
					(Select.new.bind(0, 1000, 0.2):Pattern).withName("Select (fuzzy)"),
					Blend.new
				]
			];
		}
		
		return patterns;
	}
	
	public static function getDropdowns(allowSubdividing:Bool):Array<PatternDropdown> {
		return [for(i in 0...4) new PatternDropdown(i, allowSubdividing, patterns[i], descriptions)];
	}
	
	private var group:ClickGroup;
	
	public var inputsExpected(default, null):Int;
	
	private function new(inputsExpected:Int, allowSubdividing:Bool, collection:Array<Pattern>, descriptions:Map<String, String>) {
		collection = collection.copy();
		
		if(allowSubdividing) {
			collection.push(Subdivide.unary);
			collection.push(Subdivide.binary);
			collection.push(Subdivide.ternary);
		}
		if(inputsExpected > 0) {
			collection.unshift(inputsExpected > 1 ? Pattern.chooseMultiOperator : Pattern.chooseOperator);
			collection.push(Pattern.clear);
		} else {
			collection.unshift(Pattern.chooseGenerator);
		}
		
		for(pattern in collection) {
			if(pattern.description == null) {
				pattern.description = descriptions[pattern.name.split(" ")[0]];
			}
		}
		
		super(new ArrayCollection(collection));
		
		this.inputsExpected = inputsExpected;
		
		group = new ClickGroup(this);
		group.addTargetChangeEventListener(onTargetChange);
		
		itemToText = function(data:Dynamic):String {
			if(Reflect.hasField(data, "name")) {
				return Reflect.field(data, "name");
			} else {
				return Std.string(data);
			}
		};
		
		buttonFactory = DisplayObjectFactory.withFunction(makeButton);
		
		listViewFactory = DisplayObjectFactory.withFunction(makeListView, destroyListView);
		itemRendererRecycler.update = updateItem;
	}
	
	private function makeButton():Button {
		var button:Button = new Button();
		button.toolTip = toolTip;
		return button;
	}
	
	private function makeListView():ListView {
		var listView:ListView = new ListView();
		listView.addEventListener(MouseEvent.MOUSE_WHEEL, onListViewMouseWheel, true);
		group.add(listView);
		return listView;
	}
	
	private function destroyListView(listView:ListView):Void {
		listView.removeEventListener(MouseEvent.MOUSE_WHEEL, onListViewMouseWheel, true);
		group.remove(listView);
	}
	
	private function updateItem(itemRenderer:Dynamic, state:ListViewItemState):Void {
		var textControl:ITextControl = cast(itemRenderer, ITextControl);
		textControl.text = state.text;
		textControl.toolTip = cast(state.data, Pattern).description;
	}
	
	public function getPatternByName(name:String):Null<Pattern> {
		for(pattern in dataProvider) {
			if((pattern:Pattern).name == name) {
				return pattern;
			}
		}
		
		return null;
	}
	
	private function onTargetChange(e:TargetChangeEvent):Void {
		if(e.newTarget != null
			&& Std.isOfType(e.newTarget.parent, ToggleButton)) {
			var button:ToggleButton = cast e.newTarget.parent;
			if(!button.selected) {
				@:privateAccess button.changeState(DOWN(false));
			}
		}
	}
	
	private function onListViewMouseWheel(e:MouseEvent):Void {
		e.preventDefault();
	}
	
	private override function set_toolTip(value:String):String {
		if(button != null) {
			return button.set_toolTip(value);
		} else {
			return super.set_toolTip(value);
		}
	}
}

class Subdivide extends ModuleBase {
	public static var unary:Pattern = (new Subdivide(1):Pattern).withName("Unary operator").withSpecialMeaning();
	public static var binary:Pattern = (new Subdivide(2):Pattern).withName("Binary operator").withSpecialMeaning();
	public static var ternary:Pattern = (new Subdivide(3):Pattern).withName("Ternary operator").withSpecialMeaning();
	
	public var count(default, null):Int;
	
	public function new(count:Int) {
		super(0);
		
		if(count < 1) {
			count = 1;
		} else if(count > 3) {
			count = 3;
		}
		
		this.count = count;
	}
}
