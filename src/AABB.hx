package ;


typedef PointLike = {
	var x:Float;
	var y:Float;
}

typedef RectLike = {
	var x:Float;
	var y:Float;
	var width:Float;
	var height:Float;
}


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

	/** Creates an AABB from a RectLike. */
	public function new(?rect:RectLike):Void 
	{
		if (rect != null) {
			minX = rect.x;
			minY = rect.y;
			maxX = rect.x + rect.width;
			maxY = rect.y + rect.height;
		} else {
			minX = minY = maxX = maxY = 0;
		}
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
	
	public function getCenter():PointLike
	{
		return { x:minX + .5 * (maxX - minX), y:minY + .5 * (maxY - minY) };
	}
	
	/** Resizes this instance so that tightly encloses `aabb`. */
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
	
	/** 
	 * Resizes this instance to be the intersection with `aabb`. 
	 * 
	 * Properties may be invalid (i.e. `minX` > `maxX`) if there's no interesection (check with `overlaps()` first). */
	public function intersectWith(aabb:AABB):AABB 
	{
		minX = Math.max(minX, aabb.minX);
		maxX = Math.min(maxX, aabb.maxX);
		minY = Math.max(minY, aabb.minY);
		maxY = Math.min(maxY, aabb.maxY);
		return this;
	}

	public function clone():AABB
	{
		return new AABB( { x:minX, y:minY, width:maxX - minX, height:maxY - minY } );
	}

	public function fromAABB(aabb:AABB):AABB
	{
		minX = aabb.minX;
		minY = aabb.minY;
		maxX = aabb.maxX;
		maxY = aabb.maxY;
		return this;
	}

	public function fromRect(aabb:RectLike):AABB
	{
		minX = aabb.x;
		minY = aabb.y;
		maxX = aabb.x + aabb.width;
		maxY = aabb.y + aabb.height;
		return this;
	}
	
}
