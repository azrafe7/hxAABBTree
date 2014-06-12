/*
 * This file is part of the AABBTree library for haxe (https://github.com/azrafe7/AABBTree).
 *
 * Developed by Giuseppe Di Mauro (aka azrafe7) and realeased under the MIT license (see LICENSE file).
 */

package ds.aabbtree;

import ds.aabbtree.IInsertStrategy.InsertChoice;


/**
 * Choose best node based on area.
 * 
 * @author azrafe7
 */
class InsertStrategyArea<T> implements IInsertStrategy<T>
{
	static var combinedAABB = new AABB();
	
	public function new() {}
	
	public function choose<T>(leafAABB:AABB, parent:Node<T>, ?extraData:Dynamic):InsertChoice
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
			return InsertChoice.PARENT;
		}

		// descend
		return costLeft < costRight ? InsertChoice.DESCEND_LEFT : InsertChoice.DESCEND_RIGHT;
	}
}