/*
 * This file is part of the AABBTree library for haxe (https://github.com/azrafe7/AABBTree).
 *
 * Developed by Giuseppe Di Mauro (aka azrafe7) and realeased under the MIT license (see LICENSE file).
 */

package ds.aabbtree;

import ds.aabbtree.IInsertStrategy.InsertChoice;


/**
 * Choose best node based on perimeter.
 * 
 * @author azrafe7
 */
class InsertStrategyPerimeter<T> implements IInsertStrategy<T>
{
	var combinedAABB = new AABB();
	
	public function new() {}
	
	public function choose<T>(leafAABB:AABB, parent:Node<T>, ?extraData:Dynamic):InsertChoice
	{
		var left = parent.left;
		var right = parent.right;
		var perimeter = parent.aabb.getPerimeter();

		combinedAABB.asUnionOf(parent.aabb, leafAABB);
		var combinedPerimeter = combinedAABB.getPerimeter();

		// cost of creating a new parent for this node and the new leaf
		var costParent = 2 * combinedPerimeter;

		// minimum cost of pushing the leaf further down the tree
		var costDescend = 2 * (combinedPerimeter - perimeter);

		// cost of descending into left node
		combinedAABB.asUnionOf(leafAABB, left.aabb);
		var costLeft = combinedAABB.getPerimeter() + costDescend;
		if (!left.isLeaf()) {
			costLeft -= left.aabb.getPerimeter();
		}

		// cost of descending into right node
		combinedAABB.asUnionOf(leafAABB, right.aabb);
		var costRight = combinedAABB.getPerimeter() + costDescend;
		if (!right.isLeaf()) {
			costRight -= right.aabb.getPerimeter();
		}

		// break/descend according to the minimum cost
		if (costParent < costLeft && costParent < costRight) {
			return InsertChoice.PARENT;
		}

		// descend
		return costLeft < costRight ? InsertChoice.DESCEND_LEFT : InsertChoice.DESCEND_RIGHT;
	}
}