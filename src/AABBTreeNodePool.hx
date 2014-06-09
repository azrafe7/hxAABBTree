package ;

/**
 * ...
 * @author azrafe7
 */

@:allow(AABBTree)
class AABBTreeNodePool<T>
{
	/** The pool will grow by this factor when it's empty. */
	var GROWTH_FACTOR:Float = 1.5;
	
	/** Initial capacity of the pool. */
	var capacity:Int;
	
	var freeNodes:Array<AABBTreeNode<T>>;
	
	
	function new(capacity:Int)
	{
		this.capacity = capacity;
		freeNodes = new Array<AABBTreeNode<T>>();
		for (i in 0...capacity) freeNodes.push(new AABBTreeNode(new AABB(), null));
	}
	
	/** Fetches a node from the pool (if available) or creates a new one. */
	function get(x:Float, y:Float, width:Float = 0, height:Float = 0, ?data:T, parent:AABBTreeNode<T> = null, id:Int = -1):AABBTreeNode<T>
	{
		var newNode:AABBTreeNode<T>;
		
		if (freeNodes.length > 0) {
			newNode = freeNodes.pop();
			newNode.aabb.setTo(x, y, width, height);
			newNode.data = data;
			newNode.parent = parent;
			newNode.id = id;
		} else {
			newNode = new AABBTreeNode(new AABB(x, y, width, height), data, parent, id);
			capacity = Std.int(capacity * GROWTH_FACTOR);
			grow(capacity);
		}
		
		return newNode;
	}
	
	/** Reinserts an unused node into the pool (for future use). */
	function put(node:AABBTreeNode<T>):Void 
	{
		freeNodes.push(node);
		node.parent = node.left = node.right = null;
		node.id = -1;
		node.invHeight = -1;
		node.data = null;
	}
	
	/** Resets the pool to its capacity (removing all the other nodes). */
	function reset():Void 
	{
		if (freeNodes.length > capacity) freeNodes.splice(capacity, freeNodes.length - capacity);
	}
	
	/** Grows the pool to contain `n` nodes. Nothing will be done if `n` is less than the current number of nodes. */
	function grow(n:Int):Void
	{
		var len = freeNodes.length;
		if (n <= len) return;
		
		for (i in len...n) {
			freeNodes.push(new AABBTreeNode(new AABB(), null));
		}
	}
}