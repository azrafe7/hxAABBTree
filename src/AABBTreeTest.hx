package;


import ds.AABB;
import ds.AABBTree;
import ds.aabbtree.InsertStrategyArea;
import ds.aabbtree.DebugRenderer;
import flash.display.Graphics;
import flash.display.Sprite;
import flash.display.Stage;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.filters.GlowFilter;
import flash.geom.Point;
import flash.Lib;
import flash.system.System;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import haxe.Timer;
import openfl.display.FPS;


@:publicFields
class Entity
{
	var id:Int;
	var dir:Point;
	var aabb:AABB;
	
	function new(dir:Point, aabb:AABB):Void 
	{
		this.dir = dir;
		this.aabb = aabb;
		this.id = -1;
	}
}


@:access(ds.AABBTree)
@:access(ds.aabbtree.Node)
class AABBTreeTest extends Sprite {

	// key codes
	inline static var LEFT:Int = 37;
	inline static var UP:Int = 38;
	inline static var RIGHT:Int = 39;
	inline static var DOWN:Int = 40;

	var TEXT_COLOR:Int = 0xFFFFFFFF;
	var TEXT_FONT:String = "_typewriter";
	var TEXT_SIZE:Float = 12;
	var TEXT_OUTLINE:GlowFilter = new GlowFilter(0xFF000000, 1, 2, 2, 6);

	var QUERY_COLOR:Int = 0xFFCC00;
	var RESULTS_COLOR:Int = 0xFF0000;
	var RESULTS_ALPHA:Float = .5;
	var SPEED = 6;
	
	var stageWidth:Int;
	var stageHeight:Int;
	var fps:FPS;
	
	var text:TextField;
	var g:Graphics;
	var tree:AABBTree<Entity>;
	var renderer:CustomRenderer<Entity>;
	var results:Array<Entity> = [];
	var lastQueryInfo: { time:Float, found:Int } = null;
	
	var startPoint:Point = new Point();
	var endPoint:Point = new Point();
	var queryRect:AABB = new AABB();
	var strictMode:Bool = true;
	var rayMode:Bool = false;
	var filterMode:Bool = false;
	var animMode:Bool = false;
	var dragging:Bool = false;

	var redraw:Bool = true;
	var overlay:Graphics;

	
	public function new () {
		super ();

		stageWidth = stage.stageWidth;
		stageHeight = stage.stageHeight;
		
		g = graphics;
		var overlaySprite:Sprite;
		stage.addChild(overlaySprite = new Sprite());
		overlay = overlaySprite.graphics;
		
		// instantiate the tree with a fattenDelta of 10 pixels and using area evaluation as insert strategy
		tree = new AABBTree(10, new InsertStrategyArea());
		renderer = new CustomRenderer(g);
		
		// insert entities with random aabbs (or points)
		for (i in 0...6) {
			var e = getRandomEntity();
			var aabb = e.aabb;
			e.id = tree.insertLeaf(e, aabb.x, aabb.y, aabb.width, aabb.height);
		}
		
		overlaySprite.addChild(text = getTextField("", stageWidth - 230, 5));
		overlaySprite.addChild(fps = new FPS(5, 5, 0xFFFFFF));
		fps.visible = false;
		
		stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
		stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
		stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
		//quit();
	}
	
	public function drawEntities(g:Graphics, list:Array<Entity>, color:Int, alpha:Float):Void 
	{
		for (e in list) {
			g.lineStyle(1, color, alpha);
			var aabb = e.aabb;
			if (aabb.width < .5 && aabb.height < .5) {
				g.drawCircle(aabb.x, aabb.y, 2);
			} else {
				g.beginFill(color, alpha);
				g.drawRect(aabb.x, aabb.y, aabb.width, aabb.height);
				g.endFill();
			}
		}
	}
	
	public function queryCallback(data:Entity, id:Int):HitBehaviour
	{
		if (data.aabb.width > 0 && data.aabb.height > 0) return HitBehaviour.SKIP;
		return HitBehaviour.INCLUDE;
	}

	public function clamp(value:Int, min:Int, max:Int):Int 
	{
		if (value < min) return min;
		else if (value > max) return max;
		return value;
	}
	
	public function getRandomEntity():Entity
	{
		var aabb = new AABB(Math.random() * stageWidth * .5 + 25, Math.random() * stageHeight * .6 + 25, Math.random() * 100 + 10, Math.random() * 100 + 10);
		
		// 50% chance of inserting a point (rect with size 0)
		if (Math.random() < .5) {
			aabb.width = 0;
			aabb.height = 0;
		}
		var dir = new Point(Math.random() * 2 - 1, Math.random() * 2 - 1);
		dir.normalize(4);
		var e = new Entity(dir, aabb);
		return e;
	}

	
	public function onKeyDown(e:KeyboardEvent):Void 
	{
		var syncMaxLevel = renderer.maxLevel == tree.height;

		switch (e.keyCode) 
		{
			case 27:					// ESC: quit
				quit();
			case UP, DOWN:				// inc/dec max drawn level
				renderer.maxLevel += e.keyCode == UP ? 1 : -1;
				renderer.maxLevel = clamp(renderer.maxLevel, 0, tree.height);
				syncMaxLevel = false;
				redraw = true;
			case "C".code:				// clear tree
				tree.clear();
				redraw = true;
			case "B".code:				// rebuild tree bottom-up (beware: sloow!)
				tree.rebuild();
				redraw = true;
			case RIGHT:					// add random leaf/leaves
				var count = e.shiftKey ? 10 : 1;
				for (i in 0...count) {
					var entity = getRandomEntity();
					var aabb = entity.aabb;
					entity.id = tree.insertLeaf(entity, aabb.x, aabb.y, aabb.width, aabb.height);
				}
				redraw = true;
			case LEFT:					// remove random leaf/leaves
				var count = e.shiftKey ? 10 : 1;
				for (i in 0...count) {
					var leafIds = tree.getLeavesIds();
					var leaves = tree.numLeaves;
					if (leaves > 0) {
						tree.removeLeaf(leafIds[Std.int(Math.random() * leaves)]);
					}
				}
				redraw = true;
			case "S".code:				// toggle strictMode
				strictMode = !strictMode;
				redraw = true;
			case "R".code:				// toggle rayMode
				rayMode	= !rayMode;
				redraw = true;
			case "L".code:				// toggle leafOnly rendering
				renderer.leafOnly = !renderer.leafOnly;
				redraw = true;
			case "A".code:				// toggle animMode
				animMode = !animMode;
				redraw = true;
			case "F".code:				// toggle filterMode
				filterMode = !filterMode;
				redraw = true;
			default:
		}		
		
		if (syncMaxLevel) renderer.maxLevel = tree.height;
	}
	
	public function onEnterFrame(_):Void 
	{
		if (animMode) {
			redraw = true;
			animate();
		}
		
		if (redraw) {
			query();
			g.clear();
			renderer.drawTree(tree);
		}
		redraw = false;
		
		overlay.clear();
		overlay.lineStyle(2, QUERY_COLOR, .7);
		if (rayMode) {
			overlay.moveTo(startPoint.x, startPoint.y);
			overlay.lineTo(endPoint.x, endPoint.y);
		} else {
			if (queryRect.width < .5 && queryRect.height < .5) {
				overlay.drawCircle(queryRect.x, queryRect.y, 2);
			} else {
				overlay.drawRect(queryRect.x, queryRect.y, queryRect.width, queryRect.height);
			}
		} 
		
		if (results.length > 0) drawEntities(overlay, results, RESULTS_COLOR, RESULTS_ALPHA);
		
		updateText();
	}
	
	public function animate():Void 
	{
		var ids = tree.getLeavesIds();
		for (id in ids) {
			var e = tree.getData(id);
			var aabb = e.aabb;
			
			// bounce
			aabb.x += e.dir.x;
			aabb.y += e.dir.y;
			var center = new Point(aabb.getCenterX(), aabb.getCenterY());
			if (center.x < 0) {
				aabb.x = -center.x;
				e.dir.x *= -1;
			} else if (center.x > stageWidth) {
				aabb.x = stageWidth - aabb.width * .5;
				e.dir.x *= -1;
			}
			if (center.y < 0) {
				aabb.y = -center.y;
				e.dir.y *= -1;
			} else if (center.y > stageHeight) {
				aabb.y = stageHeight - aabb.height * .5;
				e.dir.y *= -1;
			}
			
			tree.updateLeaf(e.id, aabb.x, aabb.y, aabb.width, aabb.height/*, e.dir.x, e.dir.y*/);
		}
	}
	
	public function updateText():Void 
	{
		var mem = System.totalMemory / 1024 / 1024;
		text.text = 
		#if debug
			"MEM: " + toFixed(mem) + " MB     FPS: " + fps.currentFPS + "/" + stage.frameRate + "\n" +
		#end
			"\n  mouse-drag to perform\n   queries on the tree\n\n\n" +
			"nodes            : " + tree.numNodes + "\n" +
			"leaves           : " + tree.numLeaves + "\n" +
			"height           : " + tree.height + "\n\n" +
			"[R] rayMode      : " + (rayMode ? "ON" : "OFF") + "\n" +
			"[S] strictMode   : " + (strictMode ? "ON" : "OFF") + "\n" +
			"[L] leafOnly     : " + (renderer.leafOnly ? "ON" : "OFF") + "\n" +
			"[A] animMode     : " + (animMode ? "ON" : "OFF") + "\n" +
			"[F] filterMode   : " + (filterMode ? "ON" : "OFF") + "\n\n" +
			"[RIGHT/LEFT] add/remove leaf\n" + 
			"[UP/DOWN]    inc/dec maxLevel\n" +
			"[B]          rebuild tree\n" +
			"[C]          clear tree\n\n";
			
		if (lastQueryInfo != null) {
			text.text +=
				"query time       : " + toFixed(lastQueryInfo.time, 4) + "s\n" +
				"leaves found     : " + lastQueryInfo.found;
		}
		text.text += "\n\n\nvalidation       : " + (tree.isValidationEnabled ? "ON" : "OFF");
	}

	public function toFixed(f:Float, decimals:Int = 2):String 
	{
		var pow = Math.pow(10, decimals);
		return '${Std.int(f * pow) / pow}';
	}
	
	public function onMouseMove(e:MouseEvent):Void 
	{
		if (dragging) {
			endPoint.x = e.stageX;
			endPoint.y = e.stageY;
			
			queryRect.setTo(startPoint.x, startPoint.y, endPoint.x - startPoint.x, endPoint.y - startPoint.y);
			if (endPoint.x < startPoint.x) {
				queryRect.width = startPoint.x - endPoint.x;
				queryRect.x = endPoint.x;
			}
			if (endPoint.y < startPoint.y) {
				queryRect.height = startPoint.y - endPoint.y;
				queryRect.y = endPoint.y;
			}
			redraw = true;
		}
	}
	
	public function onMouseDown(e:MouseEvent):Void 
	{
		startPoint.x = e.stageX;
		startPoint.y = e.stageY;
		endPoint.x = e.stageX;
		endPoint.y = e.stageY;
		
		queryRect.x = startPoint.x;
		queryRect.y = startPoint.y;
		queryRect.width = 0;
		queryRect.height = 0;
		
		dragging = true;
	}
	
	public function onMouseUp(e:MouseEvent):Void 
	{
		dragging = false;
		redraw = true;
	}
	
	public function query():Void 
	{
		var startTime = Timer.stamp();
		if (rayMode) results = tree.rayCast(startPoint.x, startPoint.y, endPoint.x, endPoint.y, null, filterMode ? queryCallback : null);
		else results = tree.query(queryRect.x, queryRect.y, queryRect.width, queryRect.height, strictMode, null, filterMode ? queryCallback : null);
		
		lastQueryInfo = { time:Timer.stamp() - startTime, found:results.length };
	}
	
	public function getTextField(text:String = "", x:Float, y:Float):TextField
	{
		var tf:TextField = new TextField();
		var fmt:TextFormat = new TextFormat(TEXT_FONT, null, TEXT_COLOR);
		tf.autoSize = TextFieldAutoSize.LEFT;
		fmt.align = TextFormatAlign.LEFT;
		fmt.size = TEXT_SIZE;
		tf.defaultTextFormat = fmt;
		tf.selectable = false;
		tf.x = x;
		tf.y = y;
		tf.filters = [TEXT_OUTLINE];
		tf.text = text;
		return tf;
	}
	
	public function quit():Void 
	{
		#if (flash || html5)
			System.exit(1);
		#else
			Sys.exit(1);
		#end
	}
}