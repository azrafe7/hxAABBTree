/*
 * This file is part of the AABBTree library for haxe (https://github.com/azrafe7/AABBTree).
 *
 * Developed by Giuseppe Di Mauro (aka azrafe7) and realeased under the MIT license (see LICENSE file).
 */

package ds.aabbtree;

import ds.aabbtree.Node;


enum InsertChoice {
	PARENT;			// choose parent as sibling node
	DESCEND_LEFT;	// descend left branch of the tree
	DESCEND_RIGHT;	// descent right branch of the tree
}

/**
 * Interface for strategies to apply when inserting a new leaf.
 * 
 * @author azrafe7
 */
interface IInsertStrategy<T>
{
	/** Choose which behaviour to apply in insert context. */
	public function choose<T>(leafAABB:AABB, parent:Node<T>, ?extraData:Dynamic):InsertChoice;
}