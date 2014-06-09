package ;

/**
 * ...
 * @author azrafe7
 */
@:allow(AABBTree)
@:allow(IInsertStrategy)
@:allow(AABBTreeNodePool)
class AABBTreeNode<T> 
{
	var left:AABBTreeNode<T> = null;
	var right:AABBTreeNode<T> = null;
	var parent:AABBTreeNode<T> = null;
	
	// fat AABB
	var aabb:AABB;
	
	// 0 for leafs
	var invHeight:Int = -1;
	
	var data:T;
	
	var id:Int = -1;
	
	function new(aabb:AABB, data:T, parent:AABBTreeNode<T> = null, id:Int = -1)
	{
		this.aabb = aabb;
		this.data = data;
		this.parent = parent;
		this.id = id;
	}
	
	/** If it's a leaf both left and right nodes should be null. */
	inline function isLeaf():Bool
	{
		return left == null;
	}
}
