package ;

import IInsertStrategy.InsertChoice;


/**
 * Choose best node based on manhattan distance of centroid.
 * 
 * @author azrafe7
 */
class InsertStrategyManhattan<T> implements IInsertStrategy<T>
{
	static var combinedAABB = new AABB();
	
	public function new() {}
	
	public function choose<T>(leafAABB:AABB, parent:AABBTreeNode<T>, ?extraData:Dynamic):InsertChoice
	{
		var left = parent.left;
		var right = parent.right;

		// cost of creating a new parent for this node and the new leaf
		combinedAABB.asUnionOf(parent.aabb, leafAABB);
		var costParent = Math.abs((combinedAABB.getCenterX() - parent.aabb.getCenterX()) + (combinedAABB.getCenterY() - parent.aabb.getCenterY()));
		
		// cost of descending into left node
		combinedAABB.asUnionOf(leafAABB, left.aabb);
		var costLeft = Math.abs((combinedAABB.getCenterX() - left.aabb.getCenterX()) + (combinedAABB.getCenterY() - left.aabb.getCenterY()));
		
		// cost of descending into right node
		combinedAABB.asUnionOf(leafAABB, right.aabb);
		var costRight = Math.abs((combinedAABB.getCenterX() - right.aabb.getCenterX()) + (combinedAABB.getCenterY() - right.aabb.getCenterY()));

		
		// break/descend according to the minimum cost
		if (costParent < costLeft && costParent > costRight) {
			return InsertChoice.PARENT;
		}

		// descend
		return costLeft < costRight ? InsertChoice.DESCEND_LEFT : InsertChoice.DESCEND_RIGHT;
	}
}