package;


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
import flash.geom.Rectangle;
import flash.Lib;
import flash.system.System;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import haxe.Timer;
import openfl.display.FPS;



@:access(ds.AABBTree)
@:access(ds.aabbtree.Node)
class AABBTreeTest extends Sprite {

	inline static var LEFT:Int = 37;
	inline static var UP:Int = 38;
	inline static var RIGHT:Int = 39;
	inline static var DOWN:Int = 40;

	var TEXT_COLOR:Int = 0xFFFFFFFF;
	var TEXT_FONT:String = "_typewriter";
	var TEXT_SIZE:Float = 12;
	var TEXT_OUTLINE:GlowFilter = new GlowFilter(0xFF000000, 1, 2, 2, 6);

	var QUERY_COLOR:Int = 0xFFCC00;
	var RESULTS_COLOR:Int = 0xFFFF00;
	var RESULTS_ALPHA:Float = .5;
	var SPEED = 6;
	
	var stageWidth:Int;
	var stageHeight:Int;
	var fps:FPS;
	
	var text:TextField;
	var g:Graphics;
	var tree:AABBTree<Rectangle>;
	var renderer:CustomRenderer<Rectangle>;
	var results:Array<Rectangle> = [];
	var lastQueryInfo: { time:Float, found:Int } = null;
	
	var startPoint:Point = new Point();
	var endPoint:Point = new Point();
	var queryRect:Rectangle = new Rectangle();
	var strictMode:Bool = true;
	var rayMode:Bool = false;
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
		
		tree = new AABBTree(10);
		renderer = new CustomRenderer(g);
		
		// insert random rects
		for (i in 0...3) {
			var r = getRandomRect();
			tree.insertLeaf(r.x, r.y, r.width, r.height, r);
		}
		
		// insert random points
		for (i in 0...3) {
			var r = getRandomRect();
			r.width = 0;
			r.height = 0;
			tree.insertLeaf(r.x, r.y, r.width, r.height, r);
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
	
	public function drawRects(g:Graphics, list:Array<Rectangle>):Void 
	{
		for (r in list) {
			g.lineStyle(1, RESULTS_COLOR, RESULTS_ALPHA);
			if (r.width < .5 && r.height < .5) {
				g.drawCircle(r.x, r.y, 2);
			} else {
				g.beginFill(RESULTS_COLOR, RESULTS_ALPHA);
				g.drawRect(r.x, r.y, r.width, r.height);
				g.endFill();
			}
		}
	}
	
	public function rayCallback(data:Rectangle, id:Int):HitBehaviour
	{
		return HitBehaviour.INCLUDE;
	}

	public function clamp(value:Int, min:Int, max:Int):Int 
	{
		if (value < min) return min;
		else if (value > max) return max;
		return value;
	}
	
	public function fclamp(value:Float, min:Float, max:Float):Float 
	{
		if (value < min) return min;
		else if (value > max) return max;
		return value;
	}
	
	public function getRandomRect():Rectangle
	{
		return new Rectangle(Math.random() * stageWidth * .5 + 25, Math.random() * stageHeight * .6 + 25, Math.random() * 100 + 10, Math.random() * 100 + 10);
	}

	
	public function onKeyDown(e:KeyboardEvent):Void 
	{
		if (e.keyCode == 27) quit();
		
		var syncMaxLevel = renderer.maxLevel == tree.height;
		if (e.keyCode == UP || e.keyCode == DOWN) {		// inc/dec max drawn level
			renderer.maxLevel += e.keyCode == UP ? 1 : -1;
			renderer.maxLevel = clamp(renderer.maxLevel, 0, tree.height);
			syncMaxLevel = false;
			redraw = true;
		} else if (e.keyCode == "C".code) {		// clear tree
			tree.clear();
			redraw = true;
		} else if (e.keyCode == "B".code) {		// rebuild tree bottom-up
			tree.rebuild();
			redraw = true;
		} else if (e.keyCode == RIGHT) {		// add random leaf
			var r = getRandomRect();
			if (Math.random() < .5) {	// 50% chance of inserting a point (rect with size 0)
				r.width = 0;
				r.height = 0;
			}
			tree.insertLeaf(r.x, r.y, r.width, r.height, r);
			redraw = true;
		} else if (e.keyCode == LEFT) {		// remove random leaf
			var leafIds = tree.getLeavesIds();
			var leaves = tree.numLeaves;
			if (leaves > 0) tree.removeLeaf(leafIds[Std.int(Math.random() * leaves)]);
			redraw = true;
		} else if (e.keyCode == "S".code) {		// toggle strictMode
			strictMode = !strictMode;
			redraw = true;
		} else if (e.keyCode == "R".code) {		// toggle rayMode
			rayMode	= !rayMode;
			redraw = true;
		} else if (e.keyCode == "L".code) {		// toggle leafOnly rendering
			renderer.leafOnly = !renderer.leafOnly;
			redraw = true;
		} else if (e.keyCode == "A".code) {		// toggle animMode
			animMode = !animMode;
			redraw = true;
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
			overlay.drawRect(queryRect.x, queryRect.y, queryRect.width, queryRect.height);
		} 
		
		if (results.length > 0) drawRects(overlay, results);
		
		updateText();
	}
	
	public function animate():Void 
	{
		var ids = tree.getLeavesIds();
		for (id in ids) {
			var rect = tree.getData(id);
			rect.x += Math.random() * SPEED * 2 - SPEED;
			rect.y += Math.random() * SPEED * 2 - SPEED;
			if (rect.width > 0 && rect.height > 0) {
				rect.width += Math.random() * SPEED - SPEED * .5;
				rect.height += Math.random() * SPEED - SPEED * .5;
				if (rect.width < 0) rect.width = 0;
				if (rect.height < 0) rect.height = 0;
			}
			tree.updateLeaf(id, rect.x, rect.y, rect.width, rect.height);
		}
	}
	
	public function updateText():Void 
	{
		var mem = System.totalMemory / 1024 / 1024;
		text.text = 
			//"" + toFixed(mem) + " MB / " + fps.currentFPS + " FPS\n" +
			"\n  mouse-drag to perform\n   queries on the tree\n\n\n" +
			"nodes            : " + tree.numNodes + "\n" +
			"leaves           : " + tree.numLeaves + "\n" +
			"height           : " + tree.height + "\n\n" +
			"[R] rayMode      : " + (rayMode ? "ON" : "OFF") + "\n" +
			"[S] strictMode   : " + (strictMode ? "ON" : "OFF") + "\n" +
			"[L] leafOnly     : " + (renderer.leafOnly ? "ON" : "OFF") + "\n" +
			"[A] animMode     : " + (animMode ? "ON" : "OFF") + "\n\n" +
			"[RIGHT/LEFT] add/remove leaf\n" + 
			"[UP/DOWN]    inc/dec maxLevel\n" +
			"[B]          rebuild tree\n" +
			"[C]          clear tree\n\n";
			
		if (lastQueryInfo != null) {
			text.text +=
				"query time       : " + toFixed(lastQueryInfo.time, 4) + "s\n" +
				"leaves found     : " + lastQueryInfo.found;
		}
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
		if (rayMode) results = tree.rayCast(startPoint.x, startPoint.y, endPoint.x, endPoint.y, null, rayCallback);
		else results = tree.query(queryRect.x, queryRect.y, queryRect.width, queryRect.height, strictMode);
		
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