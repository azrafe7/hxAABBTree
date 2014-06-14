/*
 * This file is part of the AABBTree library for haxe (https://github.com/azrafe7/AABBTree).
 *
 * Developed by Giuseppe Di Mauro (aka azrafe7) and realeased under the MIT license (see LICENSE file).
 */

package ds;


/**
 * Axis-Aligned Bounding Box.
 * 
 * @author azrafe7
 */
class AABB
{	
	public var minX:Float;
	public var maxX:Float;
	public var minY:Float;
	public var maxY:Float;

	public var x(get, set):Float;
	inline private function get_x():Float
	{
		return minX;
	}
	inline private function set_x(value:Float):Float
	{
		maxX += value - minX;
		return minX = value;
	}
	
	public var y(get, set):Float;
	inline private function get_y():Float
	{
		return minY;
	}
	inline private function set_y(value:Float):Float
	{
		maxY += value - minY;
		return minY = value;
	}
	
	public var width(get, set):Float;
	inline private function get_width():Float
	{
		return maxX - minX;
	}
	inline private function set_width(value:Float):Float
	{
		return maxX = minX + value;
	}
	
	public var height(get, set):Float;
	inline private function get_height():Float
	{
		return maxY - minY;
	}
	inline private function set_height(value:Float):Float
	{
		return maxY = minY + value;
	}
	
	/** 
	 * Creates an AABB from the specified parameters.
	 * 
	 * Note: `width` and `height` must be non-negative.
	 */
	public function new(x:Float = 0, y:Float = 0, width:Float = 0, height:Float = 0):Void 
	{
		minX = x;
		minY = y;
		maxX = x + width;
		maxY = y + height;
	}

	public function setTo(x:Float, y:Float, width:Float = 0, height:Float = 0):Void 
	{
		minX = x;
		minY = y;
		maxX = x + width;
		maxY = y + height;
	}

	public function inflate(deltaX:Float, deltaY:Float):AABB
	{
		minX -= deltaX;
		minY -= deltaY;
		maxX += deltaX;
		maxY += deltaY;
		return this;
	}
	
	public function getPerimeter():Float
	{
		return 2 * ((maxX - minX) + (maxY - minY));
	}
	
	public function getArea():Float
	{
		return (maxX - minX) * (maxY - minY);
	}
	
	public function getCenterX():Float
	{
		return minX + .5 * (maxX - minX);
	}
	
	public function getCenterY():Float
	{
		return minY + .5 * (maxY - minY);
	}
	
	/** Resizes this instance so that it tightly encloses `aabb`. */
	public function union(aabb:AABB):AABB
	{
		minX = Math.min(minX, aabb.minX);
		minY = Math.min(minY, aabb.minY);
		maxX = Math.max(maxX, aabb.maxX);
		maxY = Math.max(maxY, aabb.maxY);
		return this;
	}
	
	/** Resizes this instance to the union of `aabb1` and `aabb2`. */
	public function asUnionOf(aabb1:AABB, aabb2:AABB):AABB
	{
		minX = Math.min(aabb1.minX, aabb2.minX);
		minY = Math.min(aabb1.minY, aabb2.minY);
		maxX = Math.max(aabb1.maxX, aabb2.maxX);
		maxY = Math.max(aabb1.maxY, aabb2.maxY);
		return this;
	}
	
	/** Returns true if this instance intersects `aabb`. */
	public function overlaps(aabb:AABB):Bool
	{
		return !(minX > aabb.maxX || maxX < aabb.minX || minY > aabb.maxY || maxY < aabb.minY);
	}
	
	/** Returns true if this instance fully contains `aabb`. */
	public function contains(aabb:AABB):Bool
	{
		return (aabb.minX >= minX && aabb.maxX <= maxX && aabb.minY >= minY && aabb.maxY <= maxY);
	}
	
	/** Returns a new instance that is the intersection with `aabb`, or null if there's no interesection. */
	public function getIntersection(aabb:AABB):AABB 
	{
		var intersection = this.clone();
		intersection.minX = Math.max(minX, aabb.minX);
		intersection.maxX = Math.min(maxX, aabb.maxX);
		intersection.minY = Math.max(minY, aabb.minY);
		intersection.maxY = Math.min(maxY, aabb.maxY);
		return (intersection.minX > intersection.maxX || intersection.minY > intersection.maxY) ? null : intersection;
	}
	
	public function clone():AABB
	{
		return new AABB(minX, minY, maxX - minX, maxY - minY);
	}

	/** Copies values from the specified `aabb`. */
	public function fromAABB(aabb:AABB):AABB
	{
		minX = aabb.minX;
		minY = aabb.minY;
		maxX = aabb.maxX;
		maxY = aabb.maxY;
		return this;
	}
}
