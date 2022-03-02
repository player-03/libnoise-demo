package com.player03.libnoisedemo;

import libnoise.generator.Const;
import libnoise.ModuleBase;

#if macro
import haxe.macro.Expr;

using haxe.macro.Context;
using haxe.macro.TypedExprTools;
#end

@:forward(name, description, hasSpecialMeaning, withSpecialMeaning, toString)
abstract Pattern(PatternImpl) from PatternImpl {
	public static var chooseGenerator(default, null):Pattern = special("Choose...", "Select a pattern to draw it to the canvas.");
	public static var chooseOperator(default, null):Pattern = special("Choose...", "Select an operator to act on the input pattern.");
	public static var chooseMultiOperator(default, null):Pattern = special("Choose...", "Select an operator to act on the input patterns.");
	public static var clear(default, null):Pattern = special("Clear", "Joins the highlighted regions back together.");
	
	public static function special(name:String, description:String):Pattern {
		return new PatternImpl(new Const(-1), name, description).withSpecialMeaning();
	}
	
	public var inputsExpected(get, never):Int;
	private function get_inputsExpected():Int {
		if(this.module != null) {
			return 0;
		} else if(this.constructor1 != null) {
			return 1;
		} else if(this.constructor2 != null) {
			return 2;
		} else {
			return 3;
		}
	}
	
	@:from private static function fromModule(module:ModuleBase):Pattern {
		return new PatternImpl(module, Type.getClassName(Type.getClass(module)).split(".").pop());
	}
	
	#if macro
	private static var constructorMatcher:EReg = ~/new (?:com\.player03\.)?libnoise(?:demo)?\.\w+\.([A-Z]\w+)\s*\(/;
	private static function getConstructorName(constructor:Expr):String {
		return if(constructorMatcher.match(constructor.typeExpr().toString(true))) {
			constructorMatcher.matched(1);
		} else {
			"Unknown";
		}
	}
	#end
	
	@:from private static macro function fromConstructor1(constructor1:ExprOf<(ModuleBase) -> ModuleBase>):ExprOf<Pattern> {
		var name:String = getConstructorName(constructor1);
		return macro new com.player03.libnoisedemo.Pattern.PatternImpl($constructor1, $v{name});
	}
	
	@:from private static macro function fromConstructor2(constructor2:ExprOf<(ModuleBase, ModuleBase) -> ModuleBase>):ExprOf<Pattern> {
		var name:String = getConstructorName(constructor2);
		return macro new com.player03.libnoisedemo.Pattern.PatternImpl($constructor2, $v{name});
	}
	
	@:from private static macro function fromConstructor3(constructor3:ExprOf<(ModuleBase, ModuleBase, ModuleBase) -> ModuleBase>):ExprOf<Pattern> {
		var name:String = getConstructorName(constructor3);
		return macro new com.player03.libnoisedemo.Pattern.PatternImpl($constructor3, $v{name});
	}
	
	public function getModule(?input0:ModuleBase, ?input1:ModuleBase, ?input2:ModuleBase):ModuleBase {
		if(this.module != null) {
			return this.module;
		} else if(this.constructor1 != null) {
			return this.constructor1(input0);
		} else if(this.constructor2 != null) {
			return this.constructor2(input0, input1);
		} else {
			return this.constructor3(input0, input1, input2);
		}
	}
	
	public inline function withName(name:String):Pattern {
		this.name = name;
		return this;
	}
	
	public inline function withDescription(description:String):Pattern {
		this.description = description;
		return this;
	}
}

class PatternImpl {
	public var module:Null<ModuleBase> = null;
	public var constructor1:(ModuleBase) -> ModuleBase = null;
	public var constructor2:(ModuleBase, ModuleBase) -> ModuleBase = null;
	public var constructor3:(ModuleBase, ModuleBase, ModuleBase) -> ModuleBase = null;
	
	public var name:String;
	public var description:String;
	public var hasSpecialMeaning:Bool = false;
	
	public function new(?module:ModuleBase, ?constructor1:(ModuleBase) -> ModuleBase,
		?constructor2:(ModuleBase, ModuleBase) -> ModuleBase, ?constructor3:(ModuleBase, ModuleBase, ModuleBase) -> ModuleBase,
		name:String, ?description:String) {
		this.module = module;
		this.constructor1 = constructor1;
		this.constructor2 = constructor2;
		this.constructor3 = constructor3;
		this.name = name;
		this.description = description;
		
		var count:Int = 0;
		if(module != null) count++;
		if(constructor1 != null) count++;
		if(constructor2 != null) count++;
		if(constructor3 != null) count++;
		if(count != 1) {
			throw 'Expected exactly one constructor, got $count.';
		}
	}
	
	public inline function withSpecialMeaning():Pattern {
		this.hasSpecialMeaning = true;
		return this;
	}
	
	public function toString():String {
		return name;
	}
}
