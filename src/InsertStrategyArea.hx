package ;

import IInsertStrategy.InsertBehaviour;


/**
 * Choose best node based on area.
 * 
 * @author azrafe7
 */
class InsertStrategyArea<T> implements IInsertStrategy<T>
{
	static var combinedAABB = new AABB();
	
	public function new() {}
	
	public function choose<T>(leafAABB:AABB, parent:AABBTreeNode<T>, ?extraData:Dynamic):InsertBehaviour
	{
		var left = parent.left;
		var right = parent.right;
		var area = parent.aabb.getArea();

		combinedAABB.asUnionOf(parent.aabb, leafAABB);
		var combinedArea = combinedAABB.getArea();

		// cost of creating a new parent for this node and the new leaf
		var costParent = 2 * combinedArea;

		// minimum cost of pushing the leaf further down the tree
		var costDescend = 2 * (combinedArea - area);

		// cost of descending into left node
		combinedAABB.asUnionOf(leafAABB, left.aabb);
		var costLeft = combinedAABB.getArea() + costDescend;
		if (!left.isLeaf()) {
			costLeft -= left.aabb.getArea();
		}

		// cost of descending into right node
		combinedAABB.asUnionOf(leafAABB, right.aabb);
		var costRight = combinedAABB.getArea() + costDescend;
		if (!right.isLeaf()) {
			costRight -= right.aabb.getArea();
		}

		// break/descend according to the minimum cost
		if (costParent < costLeft && costParent < costRight) {
			return InsertBehaviour.PARENT;
		}

		// descend
		return costLeft < costRight ? InsertBehaviour.DESCEND_LEFT : InsertBehaviour.DESCEND_RIGHT;
	}
}