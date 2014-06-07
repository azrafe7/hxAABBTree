package ;



/**
 * ...
 * @author azrafe7
 */
class RectTools
{

	@:noUsing
	public static function getNewRect(x:Float = 0, y:Float = 0, width:Float = 0, height:Float = 0):RectLike
	{
		return { x:x, y:y, width:width, height:height };
	}
	
	public static function area(rect:RectLike):Float 
	{
		return rect.width * rect.height;
	}

	public static function unionArea(rect1:RectLike, rect2:RectLike):Float 
	{
		var minX = Math.min(rect1.x, rect2.x);
		var minY = Math.min(rect1.y, rect2.y);
		var maxX = Math.max(rect1.x + rect1.width, rect2.x + rect2.width);
		var maxY = Math.max(rect1.y + rect1.height, rect2.y + rect2.height);
		return (maxX - minX) * (maxY - minY);
	}

	public static function getUnionRect(rect1:RectLike, rect2:RectLike):RectLike 
	{
		var unionRect = clone(rect1);
		union(unionRect, rect2);
		return unionRect;
	}
	
	inline public static function clone(rect:RectLike):RectLike 
	{
		return getNewRect(rect.x, rect.y, rect.width, rect.height);
	}
	
	public static function union(rect1:RectLike, rect2:RectLike):RectLike 
	{
		rect1.x = Math.min(rect1.x, rect2.x);
		rect1.y = Math.min(rect1.y, rect2.y);
		var maxX = Math.max(rect1.x + rect1.width, rect2.x + rect2.width);
		var maxY = Math.max(rect1.y + rect1.height, rect2.y + rect2.height);
		rect1.width = maxX - rect1.x;
		rect1.height = maxY - rect1.y;
		return rect1;
	}

	public static function getIntersectionRect(rect1:RectLike, rect2:RectLike):RectLike 
	{
		var x1 = rect1.x, 		y1 = rect1.y,		// rect1 pos
			w1 = rect1.width, 	h1 = rect1.height,	// rect1 size
			x2 = rect2.x, 		y2 = rect2.y,		// rect2 pos
			w2 = rect2.width, 	h2 = rect2.height;	// rect2 size
			
		// calc bounds
		var left = Math.max(x1, x2);
		var right = Math.min(x1 + w1, x2 + w2);
		var top = Math.max(y1, y2);
		var bottom = Math.min(y1 + h1, y2 + h2);
		
		// calc size
		var width = right - left;
		var height = bottom - top;
		
		return (width < 0 || height < 0) ? getNewRect() : getNewRect(left, top, width, height);
	}
	
	static public function inflate(rect:RectLike, deltaX:Float, deltaY:Float):RectLike 
	{
		rect.x -= deltaX;
		rect.width += deltaX * 2;
		rect.y -= deltaY;
		rect.height += deltaY * 2;
		return rect;
	}
	
	static public function intersects(rect1:RectLike, rect2:RectLike):Bool {
		return !(rect1.x > rect2.x + rect2.width 
				|| rect1.x + rect1.width < rect2.x 
				|| rect1.y > rect2.y + rect2.height 
				|| rect1.y + rect1.height < rect2.y);
	}
	
	static public function contains(rect1:RectLike, rect2:RectLike):Bool {
		return (rect2.x >= rect1.x && (rect2.x + rect2.width) <= (rect1.x + rect1.width)
				&& rect2.y >= rect1.y && (rect2.y + rect2.height) <= (rect1.y + rect1.height));
	}

	static public function perimeter(rect:RectLike):Float {
		return (rect.width + rect.height) * 2;
	}

}