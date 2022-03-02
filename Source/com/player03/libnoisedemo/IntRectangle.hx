package com.player03.libnoisedemo;

import openfl.geom.Rectangle;

class IntRectangle {
	public var x:Int;
	public var y:Int;
	public var width:Int;
	public var height:Int;
	
	public var left(get, set):Int;
	public var top(get, set):Int;
	public var right(get, set):Int;
	public var bottom(get, set):Int;
	
	public function new(?x:Int = 0, ?y:Int = 0, ?width:Int = 0, ?height:Int = 0) {
		this.x = x;
		this.y = y;
		this.width = width;
		this.height = height;
	}
	
	public inline function toFloatRectangle():Rectangle {
		return new Rectangle(x, y, width, height);
	}
	
	public function clone():IntRectangle {
		return new IntRectangle(x, y, width, height);
	}
	
	public function setTo(x:Int, y:Int, width:Int, height:Int) {
		this.x = x;
		this.y = y;
		this.width = width;
		this.height = height;
	}
	
	public function copyFrom(other:IntRectangle):Void {
		this.x = other.x;
		this.y = other.y;
		this.width = other.width;
		this.height = other.height;
	}
	
	public function equals(other:IntRectangle):Bool {
		return x == other.x && y == other.y && width == other.width && height == other.height;
	}
	
	public function contains(x:Int, y:Int):Bool {
		return x >= this.x && y >= this.y && x <= right && y <= bottom;
	}
	
	public function containsRect(other:IntRectangle):Bool {
		return left <= other.left && top <= other.top && right >= other.right && bottom >= other.bottom;
	}
	
	public function toString():String {
		return '[$x, $y, $width, $height]';
	}
	
	private inline function get_left():Int
	{
		return x;
	}
	private inline function set_left(value:Int):Int
	{
		width -= value - x;
		return x = value;
	}
	
	private inline function get_top():Int
	{
		return y;
	}
	private inline function set_top(value:Int):Int
	{
		height -= value - y;
		return y = value;
	}
	
	private inline function get_right():Int
	{
		return x + width;
	}
	private inline function set_right(value:Int):Int
	{
		width = value - x;
		return value;
	}
	
	private inline function get_bottom():Int
	{
		return y + height;
	}
	private inline function set_bottom(value:Int):Int
	{
		height = value - y;
		return value;
	}
}
